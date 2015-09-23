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
      .then -> setTimeout(@loop.bind(@), 60000)
  getCurrentDate: -> # for stubbing in tests
    new Date()
  schedule: ->
    @info "Cron:schedule", @details()
    new Promise (resolve, reject) =>
      @scheduleStep(resolve, reject)
  scheduleStep: (resolve, reject) ->
    @info "Cron:scheduleStep", @details()
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
      requestAsync({method: "GET", url: "#{@url}/step/run/#{step._id}/#{@token}/#{@isDryRun}", json: true})
      .bind(@)
      .spread (response, body) ->
        return false if response.statusCode isnt 200
        refreshInterval = step.refreshInterval or 5 * 60000
        @Steps.update({_id: step._id}, {$set: {refreshPlannedAt: new Date(now.getTime() + refreshInterval)}})
        .then -> true
    .then (shouldContinue) ->
      if shouldContinue then process.nextTick(@scheduleStep.bind(@, resolve, reject))
    .catch reject

module.exports = Cron
