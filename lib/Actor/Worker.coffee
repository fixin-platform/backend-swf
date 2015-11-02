_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
errors = require "../../core/helper/errors"
mongodbEscape = require "../../core/helper/mongodb-escape"
Match = require "mtr-match"
Actor = require "../Actor"

class Worker extends Actor
  constructor: (options, dependencies) ->
    Match.check options,
      domain: String
      taskList:
        name: String
      identity: String
      taskCls: Function # ActivityTask constructor
      maxLoops: Match.Optional(Match.Integer)
      env: Match.Optional(String)
    @knex = dependencies.knex
    @bookshelf = dependencies.bookshelf
    @mongodb = dependencies.mongodb
    @redis = dependencies.redis
    Match.check @knex, Match.Any
    Match.check @bookshelf, Match.Any
    Match.check @mongodb, Match.Any
    Match.check @redis, Match.Any
    @Commands = @mongodb.collection("Commands")
    @Issues = @mongodb.collection("Issues")
    super
  name: -> "Worker"
  signature: -> ["domain", "taskList", "identity"]
  start: ->
    @verbose "Worker:starting", @details()
    @loop()
  stop: (code) ->
    @verbose "Worker:stopping", @details()
    Promise.join(@knex.destroy(), @mongodb.close())
    .bind(@)
    .catch (error) -> @error "Worker:stopping:failed", @details(error)
    .then ->
      # Don't remove extra logging
      # I'm trying to catch a bug which causes the worker to continue running even after "Worker:failed" and "Worker:stopping"
      @verbose "Worker:halting", @details
        requestIsComplete: @request.isComplete
      if @request.isComplete
        @halt(code)
      else
        @request.on "complete", @halt.bind(@, code)
        @request.abort()
  halt: (code) ->
    @verbose "Worker:stopped", @details()
    process.exit(code)
  loop: ->
    return @stop(0) if @shouldStop
    return @cease(0) if @shouldCease
    process.nextTick =>
      Promise.bind(@)
      .then @poll
      .catch (error) ->
        @error "Worker:failed", @details(error)
        @stop(1) # the process manager will restart it
      .then @checkLoop
      .then @loop
  poll: ->
    @verbose "Worker:polling", @details()
    Promise.bind(@)
    .then ->
      Promise.fromNode (callback) =>
        @request = @swf.pollForActivityTask
          domain: @domain
          taskList: @taskList
          identity: @identity
        , callback
        @request.on "complete", => @request.isComplete = true
    .then (options) ->
      return false if not options.taskToken # "Call me later", said Amazon
      input = null # make it available in .catch, but parse inside new Promise
      new Promise (resolve, reject) =>
        try
          input = JSON.parse(options.input)
          Match.check input, Match.ObjectIncluding
            commandId: String
          delete options.input
          @info "Worker:executing", @details({input: input, options: options}) # probability of exception on JSON.parse is quite low, while it's very convenient to have input in JSON
          dependencies =
            logger: @logger
            bookshelf: @bookshelf
            knex: @knex
            mongodb: @mongodb
            redis: @redis
          task = new @taskCls input, options, dependencies
          Promise.bind(@)
          .then -> @progressBarSetIsStarted input.commandId, options.activityId
          .then -> task.execute()
          .then (result) ->
            @progressBarSetIsCompleted input.commandId, options.activityId
            resolve(result)
          .catch (error) ->
            @progressBarSetIsFailed input.commandId, options.activityId
            reject(error)
        catch error
          reject(error)
      .bind(@)
      .then (result) ->
        @info "Worker:completed", @details({result: result, input: input, options: options})
        @swf.respondActivityTaskCompletedAsync
          taskToken: options.taskToken
          result: JSON.stringify result
        .bind(@)
# The following .catch() accounts for a race condition:
# * Decider schedules two activity tasks in parallel
# * SWF starts two activity tasks, delegating them to individual workers
# * Worker A fails its activity task early during execution
# * Decider fails the workflow execution
# * Worker B completes its activity task
# * SWF responds with UnknownResourceFault (because workflow execution has already been closed by Decider)
        .catch ((error) -> error.code is "UnknownResourceFault"), (error) -> @warn "Worker:UnknownResourceFault", @details({error: error})
        .then -> @info "Worker:completed:sent"
      .catch (error) ->
        details = error.toJSON?() or errors.errorToJSON(error)
        details.stack = "~ stripped for tests ~" if @env is "test" # nock will complain about non-matching record, because stack traces are different on different machines
        reason = error.message or error.name
        taskToken = options.taskToken
        now = new Date()
        # SWF expects reason to be 256 chars or less
        truncatedSuffix = " [truncated]"
        maxlength = 256 - truncatedSuffix.length
        truncatedReason = reason.substring(0, maxlength)
        if truncatedReason.length is maxlength
          truncatedReason += truncatedSuffix
        Promise.all [
          @swf.respondActivityTaskFailedAsync(
            reason: truncatedReason
            details: JSON.stringify details
            taskToken: taskToken
          )
          .catch ((error) -> error.code is "UnknownResourceFault"), (error) -> @warn "Worker:UnknownResourceFault", @details({error: error})
        ,
          @Issues.insert(
            reason: reason
            details: mongodbEscape details
            taskToken: taskToken
            commandId: input.commandId
            stepId: input.stepId
            userId: input.userId
            updatedAt: now
            createdAt: now
          )
        ]
        .catch (anotherError) -> throw anotherError # if we hit another error while reporting the original error, throw another error instead (we'll see it in console)
        .then -> throw error # otherwise let it crash with original error
      .finally @countdown
  progressBarSetIsStarted: (commandId, activityId) -> @Commands.update({_id: commandId, "progressBars.activityId": activityId}, {$set: {"progressBars.$.isStarted": true}}).then -> true
  progressBarSetIsCompleted: (commandId, activityId) -> @Commands.update({_id: commandId, "progressBars.activityId": activityId}, {$set: {"progressBars.$.isCompleted": true}}).then -> true
  progressBarSetIsFailed: (commandId, activityId) -> @Commands.update({_id: commandId, "progressBars.activityId": activityId}, {$set: {"progressBars.$.isFailed": true}}).then -> true

module.exports = Worker
