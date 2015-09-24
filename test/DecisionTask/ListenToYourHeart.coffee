_ = require "underscore"
stamp = require "../../core/helper/stamp"
DecisionTask = require "../../core/lib/Task/DecisionTask"

class ListenToYourHeart extends DecisionTask
  WorkflowExecutionStarted: (event, attributes, input) ->
    @createBarrier "CompleteWorkflowExecution", ["ListenToYourHeart"]
    @addDecision @ScheduleActivityTask "ListenToYourHeart", stamp(@input["ListenToYourHeart"], @input)

  CompleteWorkflowExecutionBarrierPassed: ->
    @addDecision @CompleteWorkflowExecution(@results["ListenToYourHeart"])

module.exports = ListenToYourHeart
