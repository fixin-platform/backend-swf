_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
createLogger = require "../../core/helper/logger"
#createKnex = require "../../core/helper/knex"
#createBookshelf = require "../../core/helper/bookshelf"
#createMongoDB = require "../../core/helper/mongodb"
settings = (require "../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/dev.json")

WorkflowExecutionHistoryGenerator = require "../../core/lib/WorkflowExecutionHistoryGenerator"
helpers = require "../helpers"

ListenToYourHeart = require "../ListenToYourHeart"

describe "ListenToYourHeart", ->
  logger = null;
  generator = null;
  task = null;

  generator = new WorkflowExecutionHistoryGenerator()
  generator.seed ->
    [
      events: [
        @WorkflowExecutionStarted
          chunks: [
            message: "h e l l o"
          ]
      ]
      decisions: [
        @ScheduleActivityTask "Echo",
          chunks: [
            message: "h e l l o"
          ]
      ]
      branches: [
        events: [@ActivityTaskCompleted "Echo"]
        decisions: [@CompleteWorkflowExecution()]
      ,
        events: [@ActivityTaskFailed "Echo"]
        decisions: [@FailWorkflowExecution()]
      ]
    ]

  before ->
    logger = createLogger settings.logger

  for history in generator.histories()
    it "should run `#{history.name}` history", ->
      task = new ListenToYourHeart(
        events: history.events
      ,
        logger: logger
      )
      task.execute()
      .then ->
        task.decisions.should.be.deep.equal(history.decisions)
