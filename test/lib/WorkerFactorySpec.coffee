#helpers = require "../helpers"
#_ = require "underscore"
#pigato = require "pigato"
#WorkerFactory = require "../../lib/WorkerFactory"
#ReadEcho = require "../ReadEcho"
#
#describe "WorkerFactory", ->
#  addr = "inproc://WorkerFactory" # must be unique per suite
#  broker = null; client = null; worker = null
#
#  beforeEach (setupDone) ->
#    broker = new pigato.Broker(addr)
#    client = new pigato.Client(addr)
#    setupDone()
#
#  afterEach (teardownDone) ->
#    broker.stop()
#    client.stop()
#    worker.stop()
#    teardownDone()
#
#  describe "normal operation", ->
#
#    beforeEach (setupDone) ->
#      setupDone()
#
#    it "should run `echo` service", (testDone) ->
#      broker.on "error", (msg) -> testDone(new Error(msg))
#      broker.start()
#
#      worker = WorkerFactory.create(addr, "EchoApi", {}, {"ReadEcho": ReadEcho})
#      worker.on "error", (msg) -> testDone(new Error(msg))
#      worker.start()
#
#      client.on "error", (msg) -> testDone(new Error(msg))
#      client.start()
#      client.onMsg = _.wrap client.onMsg.bind(client), (parent, _msg) ->
#        msg = (frame.toString() for frame in _msg)
#        parent(_msg)
#      client.request "EchoApi",
#        job: "ReadEcho"
#        options: {}
#        body: {message: "h e l l o"}
#      .on "data", (body) ->
#        return unless body # last data frame is false (pigato workaround)
#        body.message.should.be.equal("h e l l o")
#      .on "end", testDone
#
#  describe "error handling", ->
#
#    it "should return error if message format doesn't match", (testDone) ->
#      broker.on "error", (msg) -> testDone(new Error(msg))
#      broker.start()
#
#      client.on "error", (msg) -> testDone(new Error(msg))
#      client.start()
#
#      worker = WorkerFactory.create(addr, "EchoApi", {}, {}, ->)
#      worker.on "error", (msg) -> testDone(new Error(msg))
#      worker.start()
#
#      client.request("EchoApi", "hello")
#      .on "error", (msg) ->
#        msg.should.be.equal("Error: Expected object, got string")
#        testDone()
#
#
