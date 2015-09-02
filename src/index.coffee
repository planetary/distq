"use strict"

connections = require "./Database"
workers = require "./Worker"


module.exports = Task


module.exports.setup = connections.setup


module.exports.shutdown = (next) ->
    workers.shutdown()
    .then(connections.shutdown)
    .nodeify(next)
