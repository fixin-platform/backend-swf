_ = require "underscore"
Promise = require "bluebird"
Match = require "mtr-match"
Actor = require "../Actor"

class Registrar extends Actor
  constructor: (options, dependencies) ->
    super

  signature: -> []

  registerDomains: (domains) ->
    @info "Registrar:registerDomains", @details()
    Promise.all(@registerDomain(domain) for domain in domains)
  registerWorkflowTypes: (workflowTypes) ->
    @info "Registrar:registerWorkflowTypes", @details()
    Promise.all(@registerWorkflowType(workflowType) for workflowType in workflowTypes)
  registerActivityTypes: (activityTypes) ->
    @info "Registrar:registerActivityTypes", @details()
    Promise.all(@registerActivityType(activityType) for activityType in activityTypes)

  registerWorkflowTypesForDomain: (workflowTypes, domain) ->
    workflowType.domain = domain for workflowType in workflowTypes
    @registerWorkflowTypes(workflowTypes)
  registerActivityTypesForDomain: (activityTypes, domain) ->
    activityType.domain = domain for activityType in activityTypes
    @registerActivityTypes(activityTypes)

  registerDomain: (domain) ->
    @info "Registrar:registeringDomain", @details(domain)
    @swf.registerDomainAsync(domain)
    .catch ((error) -> error.code is "DomainAlreadyExistsFault"), (error) -> # noop, passthrough for other errors
  registerWorkflowType: (workflowType) ->
    @info "Registrar:registeringWorkflowType", @details(workflowType)
    @swf.registerWorkflowTypeAsync(workflowType)
    .catch ((error) -> error.code is "TypeAlreadyExistsFault"), (error) -> # noop, passthrough for other errors
  registerActivityType: (activityType) ->
    @info "Registrar:registeringActivityType", @details(activityType)
    @swf.registerActivityTypeAsync(activityType)
    .catch ((error) -> error.code is "TypeAlreadyExistsFault"), (error) -> # noop, passthrough for other errors

#  listDomains: (params) ->
#    @swf.listDomainsAsync(params).bind(@)
#    .then (data) ->
#      if data.nextPageToken
#        params = _clone params
#        params.nextPageToken = data.nextPageToken
#        promise = @listDomains(params)
#      else
#        promise = Promise.resolve([])
#      promise
#      .then (domainInfos) -> data.domainInfos.concat(domainInfos)

module.exports = Registrar