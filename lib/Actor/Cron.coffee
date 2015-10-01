_ = require "underscore"
Promise = require "bluebird"
errors = require "../../core/helper/errors"
Match = require "mtr-match"
Actor = require "../Actor"
requestAsync = Promise.promisify(require "request")
Random = require "meteor-random"

class Cron extends Actor
  constructor: (options, dependencies) ->
    Match.check options,
      domain: String
      identity: String
      maxLoops: Match.Optional(Match.Integer)
      token: String
      url: String
      timeout: Match.Integer
      isDryRunRequest: Boolean
      isDryRunWorkflowExecution: Boolean
    super
    @settings = dependencies.settings
    @swf = dependencies.swf
    @mongodb = dependencies.mongodb
    Match.check @mongodb, Match.Any
    @Commands = @mongodb.collection("Commands")
    @Issues = @mongodb.collection("Issues")
    @Steps = @mongodb.collection("Steps")
  name: -> "Cron"
  signature: -> ["domain", "identity", "url"]
  start: ->
    @verbose "Cron:starting", @details()
    @loop()
  stop: (code) ->
    @verbose "Cron:stopping", @details()
    Promise.join(@mongodb.close())
    .bind(@)
    .catch (error) -> @error "Cron:stopping:failed", @details(error)
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
      .then -> setTimeout(@loop.bind(@), @timeout)
  getCurrentDate: -> # for stubbing in tests
    new Date()
  schedule: ->
    @info "Cron:schedule", @details()
    new Promise (resolve, reject) =>
      @scheduleStep(resolve, reject)
  scheduleStep: (resolve, reject) ->
    now = @getCurrentDate()
    query =
      isAutorun: true
      refreshPlannedAt:
        $lte: now
    Promise.bind(@)
    .then -> @Steps.findAndModify(
      query: query
      sort:
        refreshPlannedAt: 1
      update:
        $set:
          refreshPlannedAt: new Date(now.getTime() + 5 * 60000) # this is only for locking; actual refreshPlannedAt is calculated based on refreshInterval
    )
    .then (findAndModifyResult) -> findAndModifyResult.value
    .then (step) ->
      if not step # findAndModify may return nothing
        resolve()
        return false
      @info "Cron:scheduleStep", @details(step)
      Promise.bind(@)
      .then ->
        if @isDryRunRequest
          [{statusCode: 200}, {}]
        else
          requestAsync
            method: "GET",
            url: "#{@url}/step/run/#{step._id}/#{@token}/#{@isDryRunWorkflowExecution}",
            json: true
            timeout: 3 * 60000 # less than default lock interval
      .spread (response, body) ->
        throw new errors.RuntimeError({response: response.toJSON(), body: body}) if response.statusCode isnt 200
      .then ->
        # Non-bugs:
        # * Cron reschedules a step to +5 minutes even when the frontend request fails
        # * Cron reschedules a step to +5 minutes irrespective of step.refreshInterval
        # These non-bugs occur because cron uses an optimistic locking algorithm
        # The current cron instance locks the step for itself, making sure that other cron instances won't process the step by updating refreshInterval to +5 minutes, thus ensuring that other cron instances won't pick up the step in the next 5 minutes
        refreshInterval = step.refreshInterval or 5 * 60000
        @Steps.update({_id: step._id}, {$set: {refreshPlannedAt: new Date(now.getTime() + refreshInterval)}})
      .thenReturn(true)
    .then (shouldContinue) ->
      if shouldContinue then process.nextTick(@scheduleStep.bind(@, resolve, reject))
    .catch reject

module.exports = Cron
