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
  signature: -> ["domain", "taskList", "identity"]
  start: ->
    @info "Decider:starting", @details()
    @loop()
  loop: ->
    return if @isStopped
    process.nextTick =>
      Promise.bind(@)
      .then @poll
      .catch (error) ->
        @error "Decider:errored", @details(error)
        throw error # let it crash and restart
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
        task = new @taskCls(options)
        task.execute()
        @info "Decider:completed", @details({decisions: task.decisions, modifier: task.modifier, options: options})
        promises = []
        promises.push @swf.respondDecisionTaskCompletedAsync({taskToken: options.taskToken, decisions: task.decisions})
        promises.push @updateCommand(options.workflowExecution.workflowId, task.modifier) unless _.isEmpty task.modifier
        Promise.all(promises)
      .catch (error) ->
        errorInJSON = errors.errorToJSON error
        @info "Decider:failed", @details({error: errorInJSON, options: options})
        throw error # rethrow, because Decider shouldn't ever fail
  updateCommand: ->

module.exports = Decider