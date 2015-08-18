_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
input = require "../../core/test-helper/input"
createDependencies = require "../../core/helper/dependencies"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")

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
        @WorkflowExecutionStarted _.defaults
          Echo:
            chunks: [
              message: "h e l l o"
            ]
        , input
      ]
      decisions: [
        @ScheduleActivityTask "Echo", _.defaults
          chunks: [
            message: "h e l l o"
          ]
        , input
      ]
      updates: [@commandSetIsStarted input.commandId]
      branches: [
        events: [@WorkflowExecutionCancelRequested()]
        decisions: [@CancelWorkflowExecution()]
        updates: []
      ,
        events: [@ActivityTaskCompleted "Echo", {chunks: [{message: "h e l l o (reply)"}]}]
        decisions: [@CompleteWorkflowExecution({message: "h e l l o (reply)"})]
        updates: [
          @commandSetIsCompleted input.commandId
          @commandSetResult input.commandId, {message: "h e l l o (reply)"}
        ]
      ,
        events: [@ActivityTaskFailed "Echo"]
        decisions: [@FailWorkflowExecution()]
        updates: [@commandSetIsFailed input.commandId]
      ]
    ]

  for history in generator.histories()
    do (history) ->
      it "should run `#{history.name}` history", ->
        task = new ListenToYourHeart(
          history.events
        ,
          activityId: "ListenToYourHeart"
        ,
          dependencies
        )
        task.execute()
        .then ->
          task.decisions.should.be.deep.equal(history.decisions)
          task.updates.should.be.deep.equal(history.updates)
