_ = require "underscore"
Promise = require "bluebird"
input = require "../core/test-helper/input"

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
  generateWorkflowExecutionParams: (workflowId, message) ->
    domain: "Dev"
    workflowId: workflowId
    workflowType:
      name: "ListenToYourHeart"
      version: "1.0.0"
    taskList:
      name: "ListenToYourHeart"
    input: JSON.stringify
      "Echo": _.defaults
        chunks: [
          message: message
        ]
        , input
