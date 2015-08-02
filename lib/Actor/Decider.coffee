_ = require "underscore"
Promise = require "bluebird"
errors = require "../../core/helper/errors"
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
    @Commands = @mongodb.collection("Commands")
  signature: -> ["domain", "taskList", "identity"]
  start: ->
    @info "Decider:starting", @details()
    @loop()
  stop: (code) ->
    @info "Decider:stopping", @details()
    process.exit(code)
  loop: ->
    return @stop(0) if @shouldStop
    process.nextTick =>
      Promise.bind(@)
      .then @poll
      .catch (error) ->
        @error "Decider:errored", @details(error)
        @stop(1) # the process manager will restart it
      .then @countdown
      .then @loop
  poll: ->
    @info "Decider:polling", @details()
    Promise.bind(@)
    .then ->
      @swf.pollForDecisionTaskAsync
        domain: @domain
        taskList: @taskList
        identity: @identity
    .then (options) ->
      return if not options.taskToken # "Call me later", said Amazon
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
#      .catch (error) ->
#        errorInJSON = errors.errorToJSON error
#        @info "Decider:failed", @details({error: errorInJSON, options: options})
#        throw error # rethrow, because Decider shouldn't ever fail
  executeCommandUpdates: (updates) ->
    Promise.all(
      for update in updates
        @Commands.update.apply(@Commands, update)
    )

module.exports = Decider
