_ = require "underscore"
DecisionTask = require "../core/lib/Task/DecisionTask"

class ListenToYourHeart extends DecisionTask
  WorkflowExecutionStarted: (event) ->
    input = JSON.parse event.workflowExecutionStartedEventAttributes.input
    @decisions.push
      decisionType: "ScheduleActivityTask"
      scheduleActivityTaskDecisionAttributes:
        activityType:
          name: "Echo"
          version: "1.0.0"
        activityId: "Echo"
        input: JSON.stringify input["Echo"]
  ActivityTaskCompleted: (event) ->
    index = _.findIndex @decisions, (decision) ->
      decision.decisionType is "ScheduleActivityTask" and decision.scheduleActivityTaskDecisionAttributes.activityId is "Echo"
    throw new Error("Can't find ScheduleActivityTask decision") if not ~index
    @decisions.splice(index, 1)
    @decisions.push
      decisionType: "CompleteWorkflowExecution"
      completeWorkflowExecutionDecisionAttributes:
        result: event.activityTaskCompletedEventAttributes.result
  ActivityTaskFailed: (event) ->
    index = _.findIndex @decisions, (decision) ->
      decision.decisionType is "ScheduleActivityTask" and decision.scheduleActivityTaskDecisionAttributes.activityId is "Echo"
    throw new Error("Can't find ScheduleActivityTask decision") if not ~index
    @decisions.splice(index, 1)
    @decisions.push
      decisionType: "FailWorkflowExecution"
      failWorkflowExecutionDecisionAttributes:
        reason: event.activityTaskFailedEventAttributes.reason
        details: event.activityTaskFailedEventAttributes.details

module.exports = ListenToYourHeart
