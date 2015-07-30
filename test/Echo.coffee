_ = require "underscore"
Promise = require "bluebird"
Match = require "mtr-match"
ActivityTask = require "../core/lib/Task/ActivityTask"

class Echo extends ActivityTask
  execute: ->
    Promise.bind(@)
    .then -> @progressBarSetTotal(0)
    .then ->
      new Promise (resolve, reject) =>
        @in.on "readable", =>
          try
            while (object = @in.read())
              Match.check object,
                message: String
              if object.message is "Schmetterling!"
                throw new Error("Too afraid!")
              else
                object.message = "#{object.message} (reply)"
                @out.write(object)
                @progressBarIncCurrent(1)
            true
          catch error
            reject(error)
        @in.on "end", resolve
        @in.on "error", reject
      .bind(@)
      .catch (error) ->
        @in.removeAllListeners()
        throw error
    .then -> @out.end()

module.exports = Echo
