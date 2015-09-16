_ = require "underscore"
Promise = require "bluebird"
errors = require "../../core/helper/errors"
mongodbEscape = require "../../core/helper/mongodb-escape"
Match = require "mtr-match"
Actor = require "../Actor"

class Decider extends Actor
  constructor: (options, dependencies) ->
    Match.check options,
      domain: String
      taskList:
        name: String
      identity: String
      taskCls: Function # DecisionTask constructor
      maxLoops: Match.Optional(Match.Integer)
    super
    @mongodb = dependencies.mongodb
    Match.check @mongodb, Match.Any
    @Issues = @mongodb.collection("Issues")
  name: -> "Decider"
  signature: -> ["domain", "taskList", "identity"]
  start: ->
    @verbose "Decider:starting", @details()
    @loop()
  stop: (code) ->
    @verbose "Decider:stopping", @details()
    Promise.join(@mongodb.close())
    .bind(@)
    .then ->
      # Don't remove extra logging
      # I'm trying to catch a bug which causes the decider to continue running even after "Decider:failed" and "Decider:stopping"
      @verbose "Decider:halting", @details
        requestIsComplete: @request.isComplete
      if @request.isComplete
        @halt(code)
      else
        @request.on "complete", @halt.bind(@, code)
        @request.abort()
  halt: (code) ->
    @verbose "Decider:stopped", @details()
    process.exit(code)
  loop: ->
    return @stop(0) if @shouldStop
    return @cease(0) if @shouldCease
    process.nextTick =>
      Promise.bind(@)
      .then @poll
      .catch (error) ->
        @error "Decider:failed", @details(error)
        @stop(1) # the process manager will restart it
      .then @countdown
      .then @loop
  poll: ->
    @verbose "Decider:polling", @details()
    Promise.bind(@)
    .then ->
      Promise.fromNode (callback) =>
        # It's possible to call @request.eachPage(callback) to get all pages or even @request.eachItem(callback) to enumerate over items with paging
        @request = @swf.pollForDecisionTask
          domain: @domain
          taskList: @taskList
          identity: @identity
        , callback
        @request.on "complete", => @request.isComplete = true
    .then (options) ->
      return if not options.taskToken # "Call me later", said Amazon
      task = null # for use in .catch
      Promise.bind(@)
      .then ->
        @info "Decider:executing", @details({options: options})
        events = options.events
        dependencies =
          logger: @logger
        delete options.events
        task = new @taskCls(events, options, dependencies)
        task.execute().bind(@)
        .then ->
          @info "Decider:completed", @details({decisions: task.decisions, updates: task.updates, options: options})
          promises = []
          promises.push @swf.respondDecisionTaskCompletedAsync({taskToken: options.taskToken, decisions: task.decisions, executionContext: task.executionContext})
          promises.push @executeCommandUpdates(task.updates)
          Promise.all(promises)
      .catch (error) ->
        details = error.toJSON?() or errors.errorToJSON(error)
        reason = error.message or error.name
        taskToken = options.taskToken
        now = new Date()
        Promise.all [
          @Issues.insert(
            reason: reason
            details: mongodbEscape details
            taskToken: taskToken
            commandId: task.input.commandId
            stepId: task.input.stepId
            userId: task.input.userId
            updatedAt: now
            createdAt: now
          )
        ]
        .then -> throw error # let it crash
  executeCommandUpdates: (updates) ->
    Promise.all(@mongodb.collection(update.collection).update(update.selector, update.modifier) for update in updates)

module.exports = Decider
