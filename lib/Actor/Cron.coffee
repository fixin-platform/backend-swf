_ = require "underscore"
Promise = require "bluebird"
errors = require "../../core/helper/errors"
Match = require "mtr-match"
Actor = require "../Actor"
requestAsync = Promise.promisify(require "request")
Random = require "meteor-random"

class Cron extends Actor
  constructor: (options, dependencies) ->
    _.defaults options,
      isDryRun: false
    Match.check options,
      domain: String
      identity: String
      maxLoops: Match.Optional(Match.Integer)
      token: String
      url: String
      isDryRun: Boolean
    super
    @settings = dependencies.settings
    @swf = dependencies.swf
    @mongodb = dependencies.mongodb
    Match.check @mongodb, Match.Any
    @Commands = @mongodb.collection("Commands")
    @Issues = @mongodb.collection("Issues")
    @Steps = @mongodb.collection("Steps")
  name: -> "Cron"
  signature: -> ["domain", "identity", "token", "url"]
  start: ->
    @verbose "Cron:starting", @details()
    @loop()
#    @interval = setInterval @workflowsRerun.bind(@), 60000
#    clearInterval(@interval)
  stop: (code) ->
    @verbose "Cron:stopping", @details()
    Promise.join(@mongodb.close())
    .bind(@)
    .then ->
      @verbose "Cron:halting", @details()
      @halt(code)
  halt: (code) ->
    @verbose "Cron:stopped", @details()
    process.exit(code)
  catchError: (error) ->
    @error "Cron:failed", @details(error)
    @stop(1) # the process manager will restart it
  loop: ->
    return @stop(0) if @shouldStop
    return @cease(0) if @shouldCease
    process.nextTick =>
      Promise.bind(@)
      .then @schedule
      .catch @catchError.bind(@)
      .then @countdown
      .then -> setTimeout(@loop.bind(@), 60000)
  getInput: (step) ->
    if @domain is "Test"
      Promise.resolve([{}, {}])
    else
      requestAsync({method: "GET", url: "#{@url}/step/input/#{step._id}/#{@token}", json: true})
  schedule: (testCommandIds) ->
    @info "Cron:schedule", @details()
    now = new Date()
    i = 0
    query =
      isAutorun: true
      refreshPlannedAt:
        $lte: now

    promiseWhile = Promise.method (condition, action) =>
      condition()
      .then (res) ->
        if res
          action().then(promiseWhile.bind(@, condition, action))

    promiseWhile =>
      @Steps.count(query)
      .then (count) ->
        count
    , =>
      @Steps.findAndModify(
        query: query
        sort:
          refreshPlannedAt: 1
        update:
          $set:
            refreshPlannedAt: new Date(now.getTime() + 5 * 60000) # this is only for locking; actual refreshPlannedAt is calculated based on refreshInterval
      )
      .then (findAndModifyResult) =>
        step = findAndModifyResult.value
        if step
          commandId = testCommandIds?[i++] or Random.id()
          @getInput(step)
          .spread (response, input) =>
            updatedAt = createdAt = new Date()
            @Commands.insert(
              _id: commandId
              input: {}
              progressBars: []
              isStarted: false
              isCompleted: false
              isFailed: false
              isDryRun: false
              isShallow: false
              stepId: step._id
              userId: step.userId
              updatedAt: updatedAt
              createdAt: createdAt
            ).then (command) =>
              _.defaults input,
                commandId: command._id
                stepId: step._id
                userId: step.userId
              params =
                domain: @domain
                workflowId: command._id
                workflowType:
                  name: step.cls
                  version: step.version or "1.0.0"
                taskList:
                  name: step.cls
                tagList: [# unused for now, but helpful in debug
                  command._id
                  step._id
                  step.userId
                ]
                input: JSON.stringify(input)
              if not @isDryRun
                @swf.startWorkflowExecutionAsync(params)
                .then (data) =>
                  @Commands.update({_id: command._id}, {$set: {runId: data.runId}})
                .catch @catchError.bind(@)

module.exports = Cron
