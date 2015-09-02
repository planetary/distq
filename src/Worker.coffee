"use strict"

acquire = require "./Database"


class Worker
    @workers = []
    @client = null

    constructor: (queue, fn) ->
        @::workers.push(this)
        if not @::client
            @::client = acquire()

        @running = true

        @queue = queue
        @fn = fn

        process.nextTick(@run)

    run: =>
        # handles a task
        @::client.blpop(queue.key)
        .then (spec) =>
            {id, args} = JSON.parse(spec)

            # create task context for the function to run in
            task = @queue.create(id)

            new bluebird (resolve, reject) ->
                # append the `resolve` function as the Node.JS style `next`
                # callback; it still expects an (err, result) pair and handles
                # it below
                args.push(resolve)

                try
                    result = fn.apply(task, args)
                    if typeof(result.then) is "function"
                        # also accept tasks that return a then-able object and
                        # assume it's spec-compliant
                        result.then(
                            (result) -> resolve(null, result),
                            resolve
                        )
                catch err
                    reject(err)
        .spread (err, result) =>
            @::client.publish(task.key, JSON.stringify(
                "err": err
                "result": result
            ))
        .then =>
            # all good
            if @running
                process.nextTick(@run)
            else
                @done()
        .catch =>
            # anything other than a redis error is a bug and should be reported
            console.error(err.stack)
            if @running
                setTimeout(@::backoff, @run)
            else
                @done()

    shutdown: (next) =>
        # stops the worker
        new bluebird (resolve, reject) =>
            if @running
                # wait for task to complete
                @done = resolve
                @running = false
            else
                # already dead; bail out
                resolve()
        .nodeify(next)

    @shutdown: (next) =>
        if @client
            # release the client if it exists
            @client.release()
            @client = null

        bluebird.all(worker.shutdown() for worker in @workers)
        .then =>
            @workers = []
            undefined
        .nodeify(next)


module.exports = Worker
