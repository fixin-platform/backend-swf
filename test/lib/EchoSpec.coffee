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
      dependencies
    )

  it "should echo messages back @fast", ->
    task.messages = [
      "h e l l o"
      "Knock, knock, Neo"
    ]
    task.execute().should.become messages: [
      "h e l l o (reply)"
      "Knock, knock, Neo (reply)"
    ]

  describe "error handling", ->

    it "should stop reading off input if it throws an exception @fast", ->
      task.messages = [
        "Schmetterling!"
        "Not read"
      ]
      task.execute().should.be.rejected
