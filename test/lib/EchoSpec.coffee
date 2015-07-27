_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createDependencies = require "../../core/helper/dependencies"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

definitions = require "../definitions/domains.json"
createSWF = require "../../core/helper/swf"
helpers = require "../helpers"

Echo = require "../Echo"

describe "Echo", ->
  dependencies = createDependencies(settings)

  task = null;

  beforeEach ->
    task = new Echo(
      {}
    ,
      {}
    ,
      in: new stream.Readable({objectMode: true})
      out: new stream.Writable({objectMode: true})
    ,
      dependencies
    )

  describe "error handling", ->

    it "should stop reading off input if it throws an exception", ->
      task.in._read = ->
        @push {message: "Schmetterling!"}
        @push {message: "Not read"}
        @push null
      task.out._write = sinon.spy()
      task.execute()
      .catch ((error) -> error.message is "Too afraid!"), ((error) ->)
      .finally ->
        task.out._write.should.have.not.been.called
