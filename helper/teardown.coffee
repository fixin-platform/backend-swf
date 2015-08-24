_ = require "underscore"
Promise = require "bluebird"

module.exports = (params, dependencies) ->
  dependencies.swf.listOpenWorkflowExecutionsAsync(params)
  .then (data) -> data.executionInfos
  .map (executionInfo) ->
    dependencies.logger.info "Teardown:terminating", executionInfo
    dependencies.swf.terminateWorkflowExecutionAsync(
      domain: params.domain
      workflowId: executionInfo.execution.workflowId
    )
