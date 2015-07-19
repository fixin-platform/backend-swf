_ = require "underscore"
AWS = require "aws-sdk"
Match = require "mtr-match"
Promise = require "bluebird"

module.exports = (options) ->
  Match.check options,
    accessKeyId: String
    secretAccessKey: String
    region: String
  Promise.promisifyAll new AWS.SWF _.extend
    apiVersion: "2012-01-25",
  , options
