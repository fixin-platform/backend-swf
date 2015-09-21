_ = require "underscore"
Promise = require "bluebird"
Match = require "mtr-match"

class Actor
  constructor: (options, dependencies) ->
    _.extend @, options
    # trigger getters
    @swf = dependencies.swf
    @logger = dependencies.logger
    Match.check @swf, Match.Any
    Match.check @logger, Match.Any
    _.defaults @,
      maxLoops: 0
      shouldCease: false
      shouldStop: false
      isCeased: false
    @logger.extend @
  details: (details = {}) ->
    if details instanceof Error
      details = {errorToString: details.toString(), error: details}
    _.extend _.pick(@, @signature()), details
  signature: -> throw new Error("Implement me!")
  countdown: ->
    return if not @maxLoops
    @maxLoops--
    @shouldStop = true if @maxLoops <= 0
  cease: (code) ->
    @verbose "#{@name()}:ceasing", @details()
    @isCeased = true
  trap: (signal) ->
    @verbose "#{@name()}:trapped", @details({signal: signal})
    switch signal
      when "SIGQUIT"
        @shouldCease = true
      when "SIGTERM"
        @shouldStop = true
        @stop(0) if @isCeased # no need to wait for another @loop() call
      else
        @stop(0)

module.exports = Actor
