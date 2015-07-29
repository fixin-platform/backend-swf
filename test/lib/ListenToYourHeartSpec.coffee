_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createDependencies = require "../../core/helper/dependencies"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

WorkflowExecutionHistoryGenerator = require "../../core/lib/WorkflowExecutionHistoryGenerator"
helpers = require "../helpers"

ListenToYourHeart = require "../ListenToYourHeart"

describe "ListenToYourHeart", ->
  dependencies = createDependencies(settings, "ListenToYourHeart")
  generator = null;
  task = null;

  generator = new WorkflowExecutionHistoryGenerator()
  generator.seed ->
    [
      events: [
        @WorkflowExecutionStarted
          chunks: [
            message: "h e l l o"
          ]
      ]
      decisions: [
        @ScheduleActivityTask "Echo",
          chunks: [
            message: "h e l l o"
          ]
      ]
      branches: [
        events: [@ActivityTaskCompleted "Echo"]
        decisions: [@CompleteWorkflowExecution()]
      ,
        events: [@ActivityTaskFailed "Echo"]
        decisions: [@FailWorkflowExecution()]
      ]
    ]

  for history in generator.histories()
    it "should run `#{history.name}` history", ->
      task = new ListenToYourHeart(
        history.events
      ,
        {}
      ,
        dependencies
      )
      task.execute()
      .then ->
        task.decisions.should.be.deep.equal(history.decisions)
