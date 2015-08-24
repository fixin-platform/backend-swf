_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
input = require "../../core/test-helper/input"
createDependencies = require "../../core/helper/dependencies"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")

domains = require "../definitions/domains.json"
workflowTypes = require "../definitions/workflowTypes.json"
activityTypes = require "../definitions/activityTypes.json"
helpers = require "../helpers"
teardown = require "../../helper/teardown"

Registrar = require "../../lib/Actor/Registrar"
exec = require "../../core/test-helper/exec"

describe "bin/teardown", ->
  dependencies = createDependencies(settings, "bin_teardown")

  registrar = null; decider = null; worker = null;

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      dependencies
    )

  afterEach ->

  it "should launch", ->
    @timeout(20000)
    @slow(10000)
    new Promise (resolve, reject) ->
      # bins are launched as separate process, so we can't record and replay their SWF requests
      nock.back "test/fixtures/teardown/Normal.json", (recordingDone) ->
        Promise.resolve()
        .then -> registrar.registerDomains(domains)
        .then -> registrar.registerWorkflowTypesForDomain(workflowTypes, "Test")
        .then -> registrar.registerActivityTypesForDomain(activityTypes, "Test")
        .then -> teardown(
          domain: "Test"
          startTimeFilter:
            oldestDate: 0
          typeFilter:
            name: "ListenToYourHeart"
            version: "1.0.0"
        ,
          dependencies
        )
        .then -> dependencies.swf.startWorkflowExecutionAsync(
          helpers.generateWorkflowExecutionParams(_.defaults(
            commandId: "HC59Fwwvdnbcu2fyi"
            stepId: "aGLB8nRHd6WMYjAeB"
          , input) , "This message won't even reach the decider")
        )
        .then -> dependencies.swf.listOpenWorkflowExecutionsAsync(
          domain: "Test"
          startTimeFilter:
            oldestDate: 0
        )
        .then (data) ->
          data.executionInfos.length.should.equal(1)
        .then -> exec "bin/teardown"
        .spread (stdout, stderr, code) ->
          stderr.should.be.equal("")
          code.should.be.equal(0)
        .then -> dependencies.swf.listOpenWorkflowExecutionsAsync(
          domain: "Test"
          startTimeFilter:
            oldestDate: 0
        )
        .then (data) ->
          data.executionInfos.length.should.equal(0)
        .then resolve
        .catch reject
        .finally recordingDone
