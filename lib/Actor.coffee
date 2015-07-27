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
      shouldStop: false
    @logger.extend @
  details: (details) -> _.extend _.pick(@, @signature()), details
  signature: -> throw new Error("Implement me!")
  countdown: ->
    return if not @maxLoops
    @maxLoops--
    @shouldStop = true if @maxLoops <= 0

module.exports = Actor