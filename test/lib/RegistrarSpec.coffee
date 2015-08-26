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

describe "Registrar", ->
  dependencies = createDependencies(settings, "Registrar")

  registrar = null

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      dependencies
    )

  describe "domains", ->

    # a domain can't be deleted, so this test won't ever pass again in record mode
    it "should register `Dev` domain @fast", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterDevDomain.json", (recordingDone) ->
          registrar.registerDomains(domains)
          .then resolve
          .catch reject
          .finally recordingDone

    it "should register `ListenToYourHeart` workflow type @fast", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterListenToYourHeartWorkflowType.json", (recordingDone) ->
          registrar.registerWorkflowTypesForDomain(workflowTypes, "Test")
          .then resolve
          .catch reject
          .finally recordingDone

    it "should register `Echo` activity type @fast", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterEchoActivityType.json", (recordingDone) ->
          registrar.registerActivityTypesForDomain(activityTypes, "Test")
          .then resolve
          .catch reject
          .finally recordingDone

  describe "error handling", ->

    it "should print the error if it happens @fast", ->
      registrar.swf.config.credentials.accessKeyId = "Santa Claus"
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterDevDomainWithInvalidCredentials.json", (recordingDone) ->
          catcherInTheRye = sinon.spy()
          registrar.registerDomains(domains)
          .catch catcherInTheRye
          .finally ->
            catcherInTheRye.should.have.been.calledWithMatch sinon.match (error) ->
              error.code is "IncompleteSignatureException"
          .then resolve
          .catch reject
          .finally recordingDone
