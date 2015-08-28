_ = require "underscore"
Promise = require "bluebird"
errors = require "../../core/helper/errors"
Match = require "mtr-match"
Actor = require "../Actor"
requestAsync = Promise.promisify(require "request")
AWS = require "aws-sdk"
Random = require "meteor-random"

class Cron extends Actor
  constructor: (options, dependencies) ->
    Match.check options,
      domain: String
      identity: String
      maxLoops: Match.Optional(Match.Integer)
    super
    @settings = dependencies.settings
    swf = new AWS.SWF _.extend
      apiVersion: "2012-01-25",
    , @settings.swf
    @startWorkflowExecutionSync = Promise.promisify(swf.startWorkflowExecution, swf)
    @mongodb = dependencies.mongodb
    Match.check @mongodb, Match.Any
    @Commands = @mongodb.collection("Commands")
    @Issues = @mongodb.collection("Issues")
    @Steps = @mongodb.collection("Steps")
  name: -> "Cron"
  signature: -> ["domain", "identity"]
  start: ->
    @info "Cron:starting", @details()
    @loop()
#    @interval = setInterval @workflowsRerun.bind(@), 60000
#    clearInterval(@interval)
  stop: (code) ->
    @info "Cron:stopping", @details()
    Promise.join(@mongodb.close())
    .bind(@)
    .then ->
      @info "Cron:halting", @details()
      @halt(code)
  halt: (code) ->
    @info "Cron:stopped", @details()
    process.exit(code)
  loop: ->
    return @stop(0) if @shouldStop
    return @cease(0) if @shouldCease
    process.nextTick =>
      Promise.bind(@)
      .then @startWorkflowExecutions
      .catch (error) ->
        @error "Cron:failed", @details(error)
        @stop(1) # the process manager will restart it
      .then @countdown
      .then -> setTimeout(@loop.bind(@), 60000)
  startWorkflowExecutions: ->
    @info "Cron:startWorkflowExecutions", @details()
    now = new Date()
    Steps = @Steps
    Commands = @Commands
    settings = @settings
    startWorkflowExecutionSync = @startWorkflowExecutionSync
    Steps.find(
      isAutorun: true
      refreshPlannedAt:
        $lte: now
    )
    .map (step) ->
      requestAsync({method: "GET", url: "#{settings.cron.url}/step/input/#{step._id}/#{settings.cron.token}", json: true})
      .spread (response, input) ->
        Commands.insert(
          _id: Random.id()
          input: {}
          progressBars: []
          isStarted: false
          isCompleted: false
          isFailed: false
          isDryRun: false
          isShallow: false
          stepId: step._id
          userId: step.userId
          updatedAt: now
          createdAt: now
        ).then (command) ->
          _.defaults input,
            commandId: command._id
            stepId: step._id
            userId: step.userId
          params =
            domain: settings.swf.domain
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
          startWorkflowExecutionSync(params)
          .then (data) ->
            Commands.update({_id: command._id}, {$set: {runId: data.runId}})
      .then ->
        Steps.update({_id: step._id}, {$set: {refreshPlannedAt: new Date(now.getTime() + 5 * 60000)}})

module.exports = Cron
