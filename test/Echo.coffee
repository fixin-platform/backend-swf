_ = require "underscore"
Promise = require "bluebird"
Match = require "mtr-match"
ActivityTask = require "../core/lib/Task/ActivityTask"

class Echo extends ActivityTask
  execute: ->
    Promise.bind(@)
    .then -> @progressBarSetTotal(0)
    .then -> @messages
    .map (message) ->
      Match.check message, String
      if message is "Schmetterling!"
        throw new Error("Too afraid!")
      else
        message = "#{message} (reply)"
      @progressBarIncCurrent(1).thenReturn(message)
    .then (messages) -> {messages: messages}

module.exports = Echo
