"use strict"

bluebird = require "bluebird"
{createClient} = require "redis"


class Connection
    constructor: (client) ->
        @client = client
        @namespace = Database.config["namespace"]
        @busy = false

        # promisify required subset of redis api
        @blpop = bluebird.promisify(client.blpop, client)
        @rpush = bluebird.promisify(client.rpush, client)
        @publish = bluebird.promisify(client.publish, client)
        @subscribe = (key) ->
            # subscribes to `key` and waits for exactly one message, then
            # unsubscribes
            new bluebird (resolve, reject) =>
                @client.once "message", (message) =>
                    if not @client.cachedMessage
                        @client.cachedMessage = message

                @client.once "error", (err) =>
                    reject(err)
                    delete @client.cachedMessage

                @client.once "subscribe", ->
                    done = true
                    resolve()
                @client.subscribe(key)

        @accept = ->
            # waits for and returns the message that was requested by a
            # previous call to subscribe
            new bluebird (resolve) =>
                if @client.cachedMessage
                    resolve(@client.cachedMessage)
                    delete @client.cachedMessage
                else
                    @client.once("message", resolve)
                    @client.once("error", reject)

        @unsubscribe = bluebird.promisify(client.unsubscribe, client)

    release: =>
        # releases this redis connection back into the pool for it to be reused
        # at a later time; it will also clear any subscribe flags in order to
        # revert the client to its original post-connected state
        @busy = false
        Database.connections.push(@)


    shutdown: (next) =>
        # terminates this connection
        if @busy
            throw new Error("Cannot shutdown connection: in use")

        new bluebird (resolve) =>
            @client.on("end", resolve)
            @client.quit()
        .nodeify(next)


Database = ->
    # returns a idle connection that's exclusively assigned to the caller
    # for graceful shutdown, it MUST be released by calling its `release`
    # method when finished with it
    if Database.connections.length
        connection = Database.connections.pop()
    else
        if Database.config["unix"]
            redis = createClient(Database.config["unix"],
                                 Database.config["options"])
        else
            redis = createClient(Database.config["port"] or 6379,
                                 Database.config["host"] or "127.0.0.1",
                                 Database.config["options"])

        redis.on "error", (err) -> console.error(err.stack)
        connection = new Connection(redis)

    connection.busy = true
    connection.client.select(Database.config["db"] or 0)
    connection


Database.connections = []
Database.config = {}


Database.setup = (config={}) ->
    # prepare redis connection parameters; the actual connection will only
    # be attempted the first time a task is registered
    Database.config = config
    undefined


Database.shutdown = (next) ->
    # shuts down all known connections
    bluebird.all(connection.shutdown() for connection in Database.connections)
    .nodeify(next)


module.exports = Database
