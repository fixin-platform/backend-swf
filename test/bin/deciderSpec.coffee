_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createLogger = require "../../core/helper/logger"
#createKnex = require "../../core/helper/knex"
#createBookshelf = require "../../core/helper/bookshelf"
#createMongoDB = require "../../core/helper/mongodb"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

definitions = require "../definitions.json"
createSWF = require "../../helper/swf"
helpers = require "../helpers"

Registrar = require "../../lib/Actor/Registrar"
execFileAsync = Promise.promisify require("child_process").execFile

describe "bin/decider", ->
  registrar = null; decider = null; worker = null;

  dependencies =
    logger: createLogger(settings.logger)
    swf: createSWF(settings.swf)

  beforeEach ->
    registrar = new Registrar(definitions, dependencies)

  afterEach ->

  it "should launch", ->
    @timeout(70000) # default Amazon timeout is 60000
    @slow(70000)
    new Promise (resolve, reject) ->
      # bins are launched as separate process, so we can't record and replay their SWF requests
      nock.back "test/fixtures/RegisterAll.json", (recordingDone) ->
        Promise.resolve()
        .then -> registrar.registerAll()
        .then -> execFileAsync("#{process.env.ROOT_DIR}/bin/decider", [
          "--config"
          "#{process.env.ROOT_DIR}/settings/dev.json"
          "--domain"
          "TestDomain"
          "--identity"
          "ListenToYourHeart-test-decider"
          "--max-loops"
          "1"
          "#{process.env.ROOT_DIR}/test/ListenToYourHeart.coffee"
        ])
        .spread (stdout, stderr) ->
          stdout.should.contain("starting")
          stdout.should.contain("polling")
          stderr.should.be.equal("")
        .then resolve
        .catch reject
        .finally recordingDone
