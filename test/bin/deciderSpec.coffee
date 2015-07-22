_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createLogger = require "../../core/helper/logger"
#createKnex = require "../../core/helper/knex"
#createBookshelf = require "../../core/helper/bookshelf"
#createMongoDB = require "../../core/helper/mongodb"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

domains = require "../definitions/domains.json"
workflowTypes = require "../definitions/workflowTypes.json"
activityTypes = require "../definitions/activityTypes.json"
createSWF = require "../../core/helper/swf"
helpers = require "../helpers"

Registrar = require "../../lib/Actor/Registrar"
execFileAsync = Promise.promisify require("child_process").execFile

describe "bin/decider", ->
  registrar = null; decider = null; worker = null;

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      logger: createLogger(settings.logger)
      swf: createSWF(settings.swf)
    )

  afterEach ->

  it "should launch", ->
    @timeout(70000) # default Amazon timeout is 60000
    @slow(70000)
    new Promise (resolve, reject) ->
      # bins are launched as separate process, so we can't record and replay their SWF requests
      nock.back "test/fixtures/RegisterAll.json", (recordingDone) ->
        Promise.resolve()
        .then -> registrar.registerDomains(domains)
        .then -> registrar.registerWorkflowTypesForDomain(workflowTypes, "TestDomain")
        .then -> registrar.registerActivityTypesForDomain(activityTypes, "TestDomain")
        .then -> execFileAsync("#{process.env.ROOT_DIR}/bin/decider", [
          "--settings"
          "#{process.env.ROOT_DIR}/settings/dev.json"
          "--domain"
          "TestDomain"
          "--identity"
          "ListenToYourHeart-test-decider"
          "--timeout"
          "10"
          "#{process.env.ROOT_DIR}/test/ListenToYourHeart.coffee"
        ])
        .spread (stdout, stderr) ->
          stdout.should.contain("starting")
          stdout.should.contain("polling")
          stderr.should.contain("TimeoutError") # we've forced that
        .then resolve
        .catch reject
        .finally recordingDone
