_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createDependencies = require "../../core/helper/dependencies"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")

domains = require "../definitions/domains.json"
workflowTypes = require "../definitions/workflowTypes.json"
activityTypes = require "../definitions/activityTypes.json"
helpers = require "../helpers"

Registrar = require "../../lib/Actor/Registrar"
exec = require "../../core/test-helper/exec"

describe "bin/decider", ->
  dependencies = createDependencies(settings, "bin_decider")

  registrar = null; decider = null; worker = null;

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      dependencies
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
        .then -> registrar.registerWorkflowTypesForDomain(workflowTypes, "Test")
        .then -> registrar.registerActivityTypesForDomain(activityTypes, "Test")
        .then -> exec "bin/decider",
          timeout: 10
        , "#{process.env.ROOT_DIR}/test/ListenToYourHeart.coffee"
        .spread (stdout, stderr, code) ->
          stderr.should.contain("NetworkingError") # we've forced that
        .then resolve
        .catch reject
        .finally recordingDone
