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

describe "bin/decider", ->
  registrar = null; decider = null; worker = null;

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      logger: createLogger(settings.logger)
      swf: createSWF(settings.swf)
    )

  describe "domains", ->

    # a domain can't be deleted, so this test won't ever pass again in record mode
    it "should register `TestDomain` domain", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterTestDomain.json", (recordingDone) ->
          registrar.registerDomains(domains)
          .then resolve
          .catch reject
          .finally recordingDone

    it "should register `ListenToYourHeart` workflow type", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterListenToYourHeartWorkflowType.json", (recordingDone) ->
          registrar.registerWorkflowTypesForDomain(workflowTypes, "TestDomain")
          .then resolve
          .catch reject
          .finally recordingDone

    it "should register `Echo` activity type", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterEchoActivityType.json", (recordingDone) ->
          registrar.registerActivityTypesForDomain(activityTypes, "TestDomain")
          .then resolve
          .catch reject
          .finally recordingDone

  describe "error handling", ->

    it "should print the error if it happens", ->
      registrar.swf.config.credentials.accessKeyId = "Santa Claus"
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/registrar/RegisterTestDomainWithInvalidCredentials.json", (recordingDone) ->
          catcherInTheRye = sinon.spy()
          registrar.registerDomains(domains)
          .catch catcherInTheRye
          .finally ->
            catcherInTheRye.should.have.been.calledWithMatch sinon.match (error) ->
              error.code is "IncompleteSignatureException"
          .then resolve
          .catch reject
          .finally recordingDone
