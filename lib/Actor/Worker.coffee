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
    @Issues = @mongodb.collection("Issues")
    super
  signature: -> ["domain", "taskList", "identity"]
  start: ->
    @info "Worker:starting", @details()
    @loop()
  stop: (code) ->
#    console.trace("Worker:stopping trace")
    @info "Worker:stopping", @details()
    @knex.destroy()
    .then -> process.exit(code)
  loop: ->
    return @stop(0) if @shouldStop
    process.nextTick =>
      Promise.bind(@)
      .then @poll
      .catch (error) ->
        @error "Worker:failed", @details(error)
        @stop(1) # the process manager will restart it
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
      input = null # make it available in .catch, but parse inside new Promise
      new Promise (resolve, reject) =>
        try
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
        catch error
          reject(error)
      .bind(@)
      .then (result) ->
        @info "Worker:completed", @details({result: result, options: options})
        @swf.respondActivityTaskCompletedAsync
          taskToken: options.taskToken
          result: JSON.stringify result
      .catch (error) ->
        details = error.toJSON?() or errors.errorToJSON(error)
        reason = error.message or error.name
        taskToken = options.taskToken
        now = new Date()
        Promise.all [
          @swf.respondActivityTaskFailedAsync
            reason: reason
            details: JSON.stringify details
            taskToken: taskToken
        ,
          @Issues.insert(
            reason: reason
            details: details
            taskToken: taskToken
            commandId: input.commandId
            stepId: input.stepId
            userId: input.userId
            updatedAt: now
            createdAt: now
          )
        ]
        .then -> throw error # let it crash

module.exports = Worker
