_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createLogger = require "../../core/helper/logger"
#createKnex = require "../../core/helper/knex"
#createBookshelf = require "../../core/helper/bookshelf"
#createMongoDB = require "../../core/helper/mongodb"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

definitions = require "../definitions/domains.json"
createSWF = require "../../core/helper/swf"
helpers = require "../helpers"

Echo = require "../Echo"

describe "Echo", ->
  logger = null;
  echo = null;

  before ->
    logger = createLogger settings.logger

  beforeEach ->
    echo = new Echo(
      {}
    ,
      {}
    ,
      in: new stream.Readable({objectMode: true})
      out: new stream.Writable({objectMode: true})
      logger: logger
    )

  describe "error handling", ->

    it "should stop reading off input if it throws an exception", ->
      echo.in._read = ->
        @push {message: "Schmetterling!"}
        @push {message: "Not read"}
        @push null
      echo.out._write = sinon.spy()
      echo.execute()
      .catch ((error) -> error.message is "Too afraid!"), ((error) ->)
      .finally ->
        echo.out._write.should.have.not.been.called
