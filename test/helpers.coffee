_ = require "underscore"
Promise = require "bluebird"

module.exports =
  clean: (swf) ->
    swf.listOpenWorkflowExecutionsAsync
      domain: "TestDomain"
      startTimeFilter:
        oldestDate: 0
      typeFilter:
        name: "ListenToYourHeart"
        version: "1.0.0"
    .then (response) ->
      Promise.all(
        for executionInfo in response.executionInfos
          swf.terminateWorkflowExecutionAsync
            domain: "TestDomain"
            workflowId: executionInfo.execution.workflowId
      )
  generateWorkflowExecutionParams: (workflowId, message) ->
    domain: "TestDomain"
    workflowId: workflowId
    workflowType:
      name: "ListenToYourHeart"
      version: "1.0.0"
    taskList:
      name: "ListenToYourHeart"
    input: JSON.stringify [{message: message}]