_ = require "underscore"
Promise = require "bluebird"
Match = require "mtr-match"
AWS = require "aws-sdk"
winston = require "winston"

class Actor
  constructor: (options, dependencies) ->
    Match.check dependencies,
      swf: AWS.SWF
      logger: winston.Logger
    _.extend @, options, dependencies
    _.defaults @,
      maxLoops: 0
      isStopped: false
    dependencies.logger.extend @
  details: (details) -> _.extend _.pick(@, @signature()), details
  countdown: ->
    return if not @maxLoops
    @maxLoops--
    @isStopped = true if @maxLoops <= 0

module.exports = Actor