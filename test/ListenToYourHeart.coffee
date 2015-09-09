_ = require "underscore"
stamp = require "../core/helper/stamp"
DecisionTask = require "../core/lib/Task/DecisionTask"

class ListenToYourHeart extends DecisionTask
  WorkflowExecutionStarted: (event, attributes, input) ->
    @createBarrier "CompleteWorkflowExecution", ["Echo"]
    @addDecision @ScheduleActivityTask "Echo", stamp(@input["Echo"], @input)

  CompleteWorkflowExecutionBarrierPassed: ->
    @addDecision @CompleteWorkflowExecution(@results["Echo"])

module.exports = ListenToYourHeart
