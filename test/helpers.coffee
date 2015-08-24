_ = require "underscore"
Promise = require "bluebird"

module.exports =
  generateWorkflowExecutionParams: (input, message) ->
    domain: "Test"
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
