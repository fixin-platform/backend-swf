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
cleanup = require "../../helper/cleanup"

Registrar = require "../../lib/Actor/Registrar"
Decider = require "../../lib/Actor/Decider"
Worker = require "../../lib/Actor/Worker"
Cron = require "../../lib/Actor/Cron"
ListenToYourHeart = require "../ListenToYourHeart"
Echo = require "../Echo"

describe "Cron", ->
  @timeout(60000) if process.env.NOCK_BACK_MODE is "record"
  @slow(500) # relevant for tests using fixtures

  dependencies = createDependencies(settings, "Cron")
  mongodb = dependencies.mongodb

  Commands = mongodb.collection("Commands")
  Issues = mongodb.collection("Issues")
  Steps = mongodb.collection("Steps")

  registrar = null; decider = null; worker = null; cron = null;

  steps =
    manualMode:
      _id: "CCykeZzwd3ZTurM3i"
      userId: "DenisGorbachev"
      cls: "ListenToYourHeart"
      isAutorun: false
    refreshPlannedAtPast:
      _id: "wwzkZTu4qvSBdqJBX"
      userId: "DenisGorbachev"
      cls: "ListenToYourHeart"
      isAutorun: true
      refreshPlannedAt: new Date(new Date().getTime() - 10000)
    refreshPlannedAtFuture:
      _id: "Kvw3vj8XFHHZ3emSx"
      userId: "DenisGorbachev"
      cls: "ListenToYourHeart"
      isAutorun: true
      refreshPlannedAt: new Date(new Date().getTime() + 10000)

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      dependencies
    )
    decider = new Decider(
      domain: "Test"
      taskList:
        name: "ListenToYourHeart"
      taskCls: ListenToYourHeart
      identity: "ListenToYourHeart-test-decider"
    ,
      dependencies
    )
    worker = new Worker(
      domain: "Test"
      taskList:
        name: "Echo"
      taskCls: Echo
      identity: "Echo-test-worker"
      env: "test"
    ,
      dependencies
    )
    cron = new Cron(
      domain: "Test"
      identity: "Cron-test-worker"
    ,
      dependencies
    )
    Promise.bind(@)
    .then ->
      Promise.all [
        Commands.remove()
        Issues.remove()
        Steps.remove()
      ]
    .then ->
      Promise.all(Steps.insert(step)  for mode, step of steps)

  describe "domains", ->
    it "should run Cron @fast", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/Cron.json", (recordingDone) ->
          Promise.resolve()
          .then -> registrar.registerDomains(domains)
          .then -> registrar.registerWorkflowTypesForDomain(workflowTypes, "Test")
          .then -> registrar.registerActivityTypesForDomain(activityTypes, "Test")
          .then -> cleanup(
            domain: "Test"
            startTimeFilter:
              oldestDate: 0
            typeFilter:
              name: "ListenToYourHeart"
              version: "1.0.0"
          ,
            dependencies
          )
          .then -> sinon.stub(Cron::, "getInput").returns(new Promise.resolve([{}, {Echo: chunks: [ message: "Hello Cron"]}]))
          .then -> cron.start("zhk6CpJ75FB2GmNCe")
          .delay(500)
          .then -> decider.poll()
          .then ->
            Commands.count().then (count) ->
              count.should.be.equal(1)
          .then ->
            Commands.findOne({stepId: steps.refreshPlannedAtPast._id}).then (command) ->
              command.isStarted.should.be.true
              command.isCompleted.should.be.false
              command.isFailed.should.be.false
          .then -> worker.poll()
          .then -> decider.poll()# CompleteWorkflowExecution or FailWorkflowExecution
          .then ->
            Commands.findOne({stepId: steps.refreshPlannedAtPast._id}).then (command) ->
              command.isStarted.should.be.true
              command.isCompleted.should.be.true
              command.isFailed.should.be.false
          .then -> Cron::getInput.restore()
          .then resolve
          .catch reject
          .finally recordingDone

  describe "error handling", ->

