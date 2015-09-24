_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
input = require "../../../core/test-helper/input"
createDependencies = require "../../../core/helper/dependencies"
settings = (require "../../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")

WorkflowExecutionHistoryGenerator = require "../../../core/lib/WorkflowExecutionHistoryGenerator"
helpers = require "../../helpers"

ListenToYourHeart = require "../../DecisionTask/ListenToYourHeart"

describe "ListenToYourHeart", ->
  dependencies = createDependencies(settings, "ListenToYourHeart")
  generator = null;
  task = null;

  generator = new WorkflowExecutionHistoryGenerator()
  generator.seed ->
    [
      events: [
        @WorkflowExecutionStarted _.defaults
          ListenToYourHeart:
            messages: [
              "h e l l o"
            ]
        , input
      ]
      decisions: [
        @ScheduleActivityTask "ListenToYourHeart", _.defaults
          messages: [
            "h e l l o"
          ]
        , input
      ]
      updates: [@commandSetIsStarted input.commandId]
      branches: [
        events: [@WorkflowExecutionCancelRequested()]
        decisions: [@CancelWorkflowExecution()]
        updates: []
      ,
        events: [@ActivityTaskCompleted "ListenToYourHeart", {messages: ["h e l l o (reply)"]}]
        decisions: [@CompleteWorkflowExecution({messages: ["h e l l o (reply)"]})]
        updates: [
          @commandSetIsCompleted input.commandId
          @commandSetResult input.commandId, {messages: ["h e l l o (reply)"]}
        ]
      ,
        events: [@ActivityTaskFailed "ListenToYourHeart"]
        decisions: [@FailWorkflowExecution()]
        updates: [@commandSetIsFailed input.commandId]
      ]
    ]

  for history in generator.histories()
    do (history) ->
      it "should run `#{history.name}` history @fast", ->
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
