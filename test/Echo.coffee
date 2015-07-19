_ = require "underscore"
Promise = require "bluebird"
Match = require "mtr-match"
ActivityTask = require "./core/lib/Task/ActivityTask"

class Echo extends ActivityTask
  constructor: (options) ->
    _.extend @, options
  execute: ->
    Promise.bind(@)
    .then ->
      new Promise (resolve, reject) =>
        @input.on "readable", =>
          try
            while (object = @input.read())
              Match.check object,
                message: String
              if object.message is "Schmetterling!"
                throw new Error("Too afraid!")
              else
                @output.write(object)
            true
          catch error
            reject(error)
        @input.on "end", resolve
        @input.on "error", reject
      .bind(@)
      .catch (error) ->
        @input.removeAllListeners()
        throw error
    .then -> @output.end()


module.exports = Echo
