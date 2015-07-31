_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
input = require "../../core/test-helper/input"
createDependencies = require "../../core/helper/dependencies"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

domains = require "../definitions/domains.json"
workflowTypes = require "../definitions/workflowTypes.json"
activityTypes = require "../definitions/activityTypes.json"
helpers = require "../helpers"

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
  
  commandIds =
    hello: "HB59Fwwvdnbcu2fyi"
    Schmetterling: "Sp7Eyt6HnmQdfuk79"
    Neo: "NJ2CsND9f6iRh2HHf"

  beforeEach ->
    registrar = new Registrar(
      {}
    ,
      dependencies
    )
    decider = new Decider(
      domain: "Dev"
      taskList:
        name: "ListenToYourHeart"
      taskCls: ListenToYourHeart
      identity: "ListenToYourHeart-test-decider"
    ,
      dependencies
    )
    worker = new Worker(
      domain: "Dev"
      taskList:
        name: "Echo"
      taskCls: Echo
      identity: "Echo-test-worker"
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
        _id: commandIds.hello
        progressBars: [
          activityId: "Echo", isStarted: false, isFinished: false
        ]
      Commands.insert
        _id: commandIds.Schmetterling
        progressBars: [
          activityId: "Echo", isStarted: false, isFinished: false
        ]
      Commands.insert
        _id: commandIds.Neo
        progressBars: [
          activityId: "Echo", isStarted: false, isFinished: false
        ]
    ]

  describe "domains", ->

    it "should run through `ListenToYourHeart` workflow multiple times", ->
      new Promise (resolve, reject) ->
        worker.details = _.wrap worker.details, (parent, args...) ->
          args[0]?.error?.stack = "~ stripped for tests ~"
          parent.apply(@, args)
        nock.back "test/fixtures/Boyband.json", (recordingDone) ->
          Promise.resolve()
          .then -> registrar.registerDomains(domains)
          .then -> registrar.registerWorkflowTypesForDomain(workflowTypes, "Dev")
          .then -> registrar.registerActivityTypesForDomain(activityTypes, "Dev")
          .then -> helpers.clean(dependencies.swf)
          # Normally, workflow execution should be started by frontend code
          .then -> dependencies.swf.startWorkflowExecutionAsync(
            helpers.generateWorkflowExecutionParams(commandIds.hello, "h e l l o")
          )
          .then -> dependencies.swf.startWorkflowExecutionAsync(
            helpers.generateWorkflowExecutionParams(commandIds.Schmetterling, "Schmetterling!")
          )
          .then -> decider.poll() # ScheduleActivityTask 1
          .then -> decider.poll() # ScheduleActivityTask 2
          .then ->
            Commands.findOne(commandIds.hello).then (command) ->
              command.progressBars[0].should.be.deep.equal activityId: "Echo", isStarted: true, isFinished: false
          .then ->
            Commands.findOne(commandIds.Schmetterling).then (command) ->
              command.progressBars[0].should.be.deep.equal activityId: "Echo", isStarted: true, isFinished: false
          .then -> worker.poll() # hello Completed or Schmetterling Failed (depends on SWF ordering of activity tasks)
          .then -> worker.poll() # hello Completed or Schmetterling Failed (depends on SWF ordering of activity tasks)
          .catch ((error) -> error.message is "Too afraid!"), ((error) ->) # catch it
          .then ->
            Commands.findOne(commandIds.hello).then (command) ->
              command.progressBars[0].should.be.deep.equal activityId: "Echo", total: 0, current: 1, isStarted: true, isFinished: false
          .then ->
            Commands.findOne(commandIds.Schmetterling).then (command) ->
              command.progressBars[0].should.be.deep.equal activityId: "Echo", total: 0, isStarted: true, isFinished: false # no current, because the Worker has failed
          .then -> decider.poll() # CompleteWorkflowExecution or FailWorkflowExecution
          .then -> decider.poll() # CompleteWorkflowExecution or FailWorkflowExecution
          .then ->
            Commands.findOne(commandIds.hello).then (command) ->
              command.progressBars[0].should.be.deep.equal activityId: "Echo", total: 0, current: 1, isStarted: true, isFinished: true
          .then ->
            Commands.findOne(commandIds.Schmetterling).then (command) ->
              command.progressBars[0].should.be.deep.equal activityId: "Echo", total: 0, isStarted: true, isFinished: true
          .then -> dependencies.swf.startWorkflowExecutionAsync(
            helpers.generateWorkflowExecutionParams(commandIds.Neo, "Knock, knock, Neo")
          )
          .then -> decider.poll() # ScheduleActivityTask 3
          .then -> worker.poll() # Echo 3 Completed
          .then -> decider.poll() # CompleteWorkflowExecution
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
