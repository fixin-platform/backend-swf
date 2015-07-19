_ = require "underscore"
helpers = require "../helpers"
Promise = require "bluebird"
execFileAsync = Promise.promisify require("child_process").execFile
createLogger = require "../../core/helper/logger"
createSWF = require "../../helper/swf"
Registrar = require "../../lib/Actor/Registrar"
definitions = require "../definitions.json"
config = require "../config.json"

describe "bin/decider", ->
  registrar = null;

  dependencies =
    logger: createLogger(config.logger)
    swf: createSWF(config.swf)

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
        .then -> execFileAsync("#{process.env.ROOT_DIR}/bin/worker", [
          "--config"
          "#{process.env.ROOT_DIR}/test/config.json"
          "--domain"
          "TestDomain"
          "--identity"
          "Echo-test-worker"
          "--max-loops"
          "1"
          "#{process.env.ROOT_DIR}/test/Echo.coffee"
        ])
        .spread (stdout, stderr) ->
          stdout.should.contain("starting")
          stdout.should.contain("polling")
          stderr.should.be.equal("")
        .then resolve
        .catch reject
        .finally recordingDone
