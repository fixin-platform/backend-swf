_ = require "underscore"
Promise = require "bluebird"

module.exports =
  clean: (swf) ->
    swf.listOpenWorkflowExecutionsAsync
      domain: "Dev"
      startTimeFilter:
        oldestDate: 0
      typeFilter:
        name: "ListenToYourHeart"
        version: "1.0.0"
    .then (response) ->
      Promise.all(
        for executionInfo in response.executionInfos
          swf.terminateWorkflowExecutionAsync
            domain: "Dev"
            workflowId: executionInfo.execution.workflowId
      )
  generateWorkflowExecutionParams: (input, message) ->
    domain: "Dev"
    workflowId: input.commandId
    workflowType:
      name: "ListenToYourHeart"
      version: "1.0.0"
    taskList:
      name: "ListenToYourHeart"
    input: JSON.stringify _.defaults
      Echo:
        chunks: [
          message: message
        ]
    , input
