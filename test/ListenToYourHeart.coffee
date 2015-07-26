_ = require "underscore"
DecisionTask = require "../core/lib/Task/DecisionTask"

class ListenToYourHeart extends DecisionTask
  WorkflowExecutionStarted: (event, attributes, input) ->
    @input = input
    @results = {}
    @createBarrier "CompleteWorkflowExecution", ["Echo"]
    @decisions.push @ScheduleActivityTask "Echo", @input["Echo"]

  ActivityTaskScheduled: (event, attributes, input) ->
    index = _.findIndex @decisions, (decision) -> decision.decisionType is "ScheduleActivityTask" and decision.scheduleActivityTaskDecisionAttributes.activityId is attributes.activityId
    throw new Error("Can't find ScheduleActivityTask(#{attributes.activityId}) decision") if not ~index
    @decisions.splice(index, 1)

  ActivityTaskCompleted: (event, attributes, result) ->
    activityTaskScheduledEvent = _.findWhere @events, {eventId: attributes.scheduledEventId}
    activityId = activityTaskScheduledEvent.activityTaskScheduledEventAttributes.activityId
    @results[activityId] = result
    @removeObstacle activityId

  ActivityTaskFailed: (event, attributes) ->
    @removeObstacle attributes.activityId
    @decisions.push
      decisionType: "FailWorkflowExecution"
      failWorkflowExecutionDecisionAttributes:
        reason: attributes.reason
        details: attributes.details

  CompleteWorkflowExecutionBarrierPassed: ->
    @decisions.push
      decisionType: "CompleteWorkflowExecution"
      completeWorkflowExecutionDecisionAttributes:
        result: JSON.stringify @results["Echo"]

module.exports = ListenToYourHeart
