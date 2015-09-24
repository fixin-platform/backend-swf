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

describe "bin/cron", ->
  dependencies = createDependencies(settings, "bin_cron")
  mongodb = dependencies.mongodb

  Commands = mongodb.collection("Commands")
  Steps = mongodb.collection("Steps")

  registrar = null; decider = null; worker = null;

  step =
    _id: "wwzkZTu4qvSBdqJBX"
    userId: "DenisGorbachev"
    cls: "ListenToYourHeart"
    isAutorun: true
    refreshPlannedAt: new Date(new Date().getTime() - 10000)

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      dependencies
    )
    Promise.bind(@)
    .then ->
      Promise.all [
        Commands.remove()
        Steps.remove()
      ]
    .then -> Steps.insert(step)

  afterEach ->

  it "should launch @fast", ->
    @timeout(70000) # default Amazon timeout is 60000
    @slow(70000)
    new Promise (resolve, reject) ->
      # bins are launched as separate process, so we can't record and replay their SWF requests
      nock.back "test/fixtures/RegisterAll.json", (recordingDone) ->
        Promise.bind(@)
        .then -> registrar.registerDomains(domains)
        .then -> registrar.registerWorkflowTypesForDomain(workflowTypes, "Test")
        .then -> registrar.registerActivityTypesForDomain(activityTypes, "Test")
        .then -> exec("bin/cron",
          token: "T252d4WerylYPZGabdYnz72910E954Zzm"
          url: "http://localhost:3000"
          timeout: 10
        )
        .spread (stdout, stderr, code) ->
          stderr.should.contain("ECONNREFUSED") # we've forced that
        .then @assertScopesFinished
        .then resolve
        .catch reject
        .finally recordingDone
