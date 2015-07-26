_ = require "underscore"
Promise = require "bluebird"
Match = require "mtr-match"

class Actor
  constructor: (options, dependencies) ->
    Match.check dependencies, Match.ObjectIncluding
      swf: Match.Any
      logger: Match.Any
    _.extend @, options, dependencies
    _.defaults @,
      maxLoops: 0
      isStopped: false
    dependencies.logger.extend @
  details: (details) -> _.extend _.pick(@, @signature()), details
  signature: -> throw new Error("Implement me!")
  countdown: ->
    return if not @maxLoops
    @maxLoops--
    @isStopped = true if @maxLoops <= 0

module.exports = Actor