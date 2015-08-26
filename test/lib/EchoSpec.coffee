_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
input = require "../../core/test-helper/input"
createDependencies = require "../../core/helper/dependencies"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")

definitions = require "../definitions/domains.json"
createSWF = require "../../core/helper/swf"
helpers = require "../helpers"

Echo = require "../Echo"

describe "Echo", ->
  dependencies = createDependencies(settings, "Echo")

  task = null;

  beforeEach ->
    task = new Echo(
      _.defaults {}, input
    ,
      {}
    ,
      in: new stream.Readable({objectMode: true})
      out: new stream.Writable({objectMode: true})
    ,
      dependencies
    )

  describe "error handling", ->

    it "should stop reading off input if it throws an exception @fast", ->
      task.in._read = ->
        @push {message: "Schmetterling!"}
        @push {message: "Not read"}
        @push null
      task.out._write = sinon.spy()
      task.execute()
      .catch ((error) -> error.message is "Too afraid!"), ((error) ->)
      .finally ->
        task.out._write.should.have.not.been.called
