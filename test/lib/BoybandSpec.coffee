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
ListenToYourHeart = require "../ListenToYourHeart"
Echo = require "../Echo"

describe "Boyband: Decider & Worker", ->
  @timeout(30000) if process.env.NOCK_BACK_MODE is "record"
  @slow(500) # relevant for tests using fixtures

  dependencies = createDependencies(settings, "Boyband")
  mongodb = dependencies.mongodb;

  Credentials = mongodb.collection("Credentials")
  Commands = mongodb.collection("Commands")
  Issues = mongodb.collection("Issues")

  registrar = null; decider = null; worker = null;

  inputs =
    hello: _.defaults
      commandId: "HC59Fwwvdnbcu2fyi"
      stepId: "aGLB8nRHd6WMYjAeB"
    , input
    Schmetterling: _.defaults
      commandId: "SC7Eyt6HnmQdfuk79"
      stepId: "SSqRtZSdND2WoDkwM"
    , input
    Neo: _.defaults
      commandId: "NC2CsND9f6iRh2HHf"
      stepId: "NSEZvsapGgGiE5Qw4"
    , input
    Bork: _.defaults
      commandId: "BCCan2oRhKtCL8jQa"
      stepId: "BSrLMhAvAzyXrsvxe"
    , input

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
    Promise.bind(@)
    .then ->
    Promise.all [
      Commands.remove()
      Issues.remove()
    ]
    .then ->
    Promise.all [
      Commands.insert
        _id: inputs.hello.commandId
        progressBars: [
          activityId: "Echo", isStarted: false, isCompleted: false, isFailed: false
        ]
        isStarted: false, isCompleted: false, isFailed: false
      Commands.insert
        _id: inputs.Schmetterling.commandId
        progressBars: [
          activityId: "Echo", isStarted: false, isCompleted: false, isFailed: false
        ]
        isStarted: false, isCompleted: false, isFailed: false
      Commands.insert
        _id: inputs.Neo.commandId
        progressBars: [
          activityId: "Echo", isStarted: false, isCompleted: false, isFailed: false
        ]
        isStarted: false, isCompleted: false, isFailed: false
    ]

  describe "domains", ->

    it "should run through `ListenToYourHeart` workflow multiple times @fast", ->
      new Promise (resolve, reject) ->
        nock.back "test/fixtures/Boyband.json", (recordingDone) ->
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
          # Normally, workflow execution should be started by frontend code
          .then -> dependencies.swf.startWorkflowExecutionAsync(
            helpers.generateWorkflowExecutionParams(inputs.hello, "h e l l o")
          )
          .then -> dependencies.swf.startWorkflowExecutionAsync(
            helpers.generateWorkflowExecutionParams(inputs.Schmetterling, "Schmetterling!")
          )
          .then -> decider.poll() # ScheduleActivityTask 1
          .then -> decider.poll() # ScheduleActivityTask 2
          .then ->
            Commands.findOne(inputs.hello.commandId).then (command) ->
              if not command # try debugging the Snap CI error
                return Promise.join(
                  mongodb.collection("Commands").find().then -> console.log 'mongodb.collection("Commands")', arguments
                ,
                  Commands.find().then -> console.log 'Commands', arguments
                ,
                  mongodb.getCollectionNames().then -> console.log 'getCollectionNames', arguments
                )
              command.isStarted.should.be.true
              command.isCompleted.should.be.false
              command.isFailed.should.be.false
          .then ->
            Commands.findOne(inputs.Schmetterling.commandId).then (command) ->
              command.isStarted.should.be.true
              command.isCompleted.should.be.false
              command.isFailed.should.be.false
          .then -> worker.poll() # hello Completed or Schmetterling Failed (depends on SWF ordering of activity tasks)
          .then -> worker.poll() # hello Completed or Schmetterling Failed (depends on SWF ordering of activity tasks)
          .catch ((error) -> error.message is "Too afraid!"), ((error) ->) # catch it
          .then ->
            Issues.find()
            .then (issues) ->
              issues.length.should.be.equal(1)
              issues[0].reason.should.be.equal("Too afraid!")
              issues[0].commandId.should.be.equal(inputs.Schmetterling.commandId)
              issues[0].stepId.should.be.equal(inputs.Schmetterling.stepId)
              issues[0].userId.should.be.equal(inputs.Schmetterling.userId)
          .then ->
            Commands.findOne(inputs.hello.commandId).then (command) ->
              EchoProgressBar = command.progressBars[0]
              EchoProgressBar.activityId.should.be.equal("Echo")
              EchoProgressBar.total.should.be.equal(0)
              EchoProgressBar.current.should.be.equal(1)
          .then ->
            Commands.findOne(inputs.Schmetterling.commandId).then (command) ->
              EchoProgressBar = command.progressBars[0]
              EchoProgressBar.activityId.should.be.equal("Echo")
              EchoProgressBar.total.should.be.equal(0)
              should.not.exist(EchoProgressBar.current) # Worker has failed, so he couldn't set current
          .then -> decider.poll() # CompleteWorkflowExecution or FailWorkflowExecution
          .then -> decider.poll() # CompleteWorkflowExecution or FailWorkflowExecution
          .then ->
            Commands.findOne(inputs.hello.commandId).then (command) ->
              command.isStarted.should.be.true
              command.isCompleted.should.be.true
              command.isFailed.should.be.false
              command.result.should.be.deep.equal({messages: ["h e l l o (reply)"]})
          .then ->
            Commands.findOne(inputs.Schmetterling.commandId).then (command) ->
              command.isStarted.should.be.true
              command.isCompleted.should.be.false
              command.isFailed.should.be.true
              should.not.exist(command.result)
          .then -> dependencies.swf.startWorkflowExecutionAsync(
            helpers.generateWorkflowExecutionParams(inputs.Neo, "Knock, knock, Neo")
          )
          .then -> decider.poll() # ScheduleActivityTask 3
          .then -> worker.poll() # Echo 3 Completed
          .then -> decider.poll() # CompleteWorkflowExecution
          .then -> dependencies.swf.startWorkflowExecutionAsync(
            helpers.generateWorkflowExecutionParams(inputs.Bork, "Bork!")
          )
          .then -> sinon.stub(ListenToYourHeart::, "WorkflowExecutionStarted").throws(new Error("Bork!"))
          .then -> decider.poll() # Exception
          .catch ((error) -> error.message is "Bork!"), ((error) ->) # catch it
          .then ->
            Issues.find().sort({createdAt: 1})
            .then (issues) ->
              issues.length.should.be.equal(2)
              issues[1].reason.should.be.equal("Bork!")
              issues[1].commandId.should.be.equal(inputs.Bork.commandId)
              issues[1].stepId.should.be.equal(inputs.Bork.stepId)
              issues[1].userId.should.be.equal(inputs.Bork.userId)
          .then -> ListenToYourHeart::WorkflowExecutionStarted.restore()
          .then resolve
          .catch reject
          .finally recordingDone

  describe "error handling", ->

#
#      client.on "error", (msg) -> testDone(new Error(msg))
#      client.start()
#
#      worker = WorkerFactory.create(addr, "EchoApi", {}, {}, ->)
#      worker.on "error", (msg) -> testDone(new Error(msg))
#      worker.start()
#
#      client.request("EchoApi", "hello")
#      .on "error", (msg) ->
#        msg.should.be.equal("Error: Expected object, got string")
#        testDone()
#
