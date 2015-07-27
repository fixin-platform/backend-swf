_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
errors = require "../../core/helper/errors"
Match = require "mtr-match"
Actor = require "../Actor"

class Worker extends Actor
  constructor: (options, dependencies) ->
    Match.check options,
      domain: String
      taskList:
        name: String
      identity: String
      taskCls: Function # ActivityTask constructor
      maxLoops: Match.Optional(Match.Integer)
    @knex = dependencies.knex
    @bookshelf = dependencies.bookshelf
    @mongodb = dependencies.mongodb
    Match.check @knex, Match.Any
    Match.check @bookshelf, Match.Any
    Match.check @mongodb, Match.Any
    super
  signature: -> ["domain", "taskList", "identity"]
  start: ->
    @info "Worker:starting", @details()
    @loop()
  loop: ->
    return if @isStopped
    process.nextTick =>
      Promise.bind(@)
      .then @poll
      .catch (error) ->
        @error "Worker:errored", @details(error)
        @knex.destroy()
        .then -> throw error # let it crash and restart
      .then @countdown
      .then @loop
  poll: ->
    @info "Worker:polling", @details()
    Promise.bind(@)
    .then ->
      @swf.pollForActivityTaskAsync
        domain: @domain
        taskList: @taskList
        identity: @identity
    .then (options) ->
      return false if not options.taskToken # "Call me later", said Amazon
      new Promise (resolve, reject) =>
        input = JSON.parse(options.input)
        @info "Worker:executing", @details({input: input, options: options}) # probability of exception on JSON.parse is quite low, while it's very convenient to have input in JSON
        inchunks = input.chunks or []
        outchunks = []
        streams =
          in: new stream.Readable({objectMode: true})
          out: new stream.Writable({objectMode: true})
        streams.in.on "error", reject
        streams.in._read = ->
          @push object for object in inchunks
          @push null # end stream
        streams.out.on "error", reject
        streams.out._write = (chunk, encoding, callback) ->
          outchunks.push chunk
          callback()
        delete input.chunks
        delete options.input
        dependencies =
          logger: @logger
          bookshelf: @bookshelf
          knex: @knex
          mongodb: @mongodb
        task = new @taskCls input, options, streams, dependencies
        task.execute().bind(@)
        .then -> resolve _.extend {chunks: outchunks}, task.result
        .catch reject
      .bind(@)
      .then (result) ->
        @info "Worker:completed", @details({result: result, options: options})
        @swf.respondActivityTaskCompletedAsync
          taskToken: options.taskToken
          result: JSON.stringify result
      .catch (error) ->
        errorInJSON = errors.errorToJSON error
        @info "Worker:failed", @details({error: errorInJSON, options: options})
        @swf.respondActivityTaskFailedAsync
          taskToken: options.taskToken
          reason: error.name
          details: JSON.stringify errorInJSON
        # don't rethrow the error, because Worker can fail

module.exports = Worker