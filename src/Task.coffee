"use strict"

bluebird = require "bluebird"
uuid = require "uuid"

acquire = require "./Database"
Queue = require "./Queue"
Worker = require "./Worker"


Task = (id, options, fn) ->
    # create and return a new queue object that when called will enqueue `fn`
    # for execution on any worker node, and asynchronously return its result
    queue = (next) ->
        if typeof(arguments[arguments.length-1]) is "function"
            # if the last argument is a function, assume it's a node `next` cb
            next = Array::pop.apply(arguments)

        task = queue.create(uuid.v4().replace(/-/g, ""))

        client = acquire()
        client.subscribe(task.key)
        .then ->
            spec = JSON.stringify("id": task.id, "args": arguments)
            Task::client.rpush(queue.key, spec)
        .then ->
            client.accept()
        .then (message) ->
            {err, result} = JSON.parse(message)
            if err
                throw err

            return result
        .finally ->
            client.release()
        .nodeify(next)

    # ensure `queue` is an instance of `Queue`
    queue["__proto__"] = Queue.prototype
    queue.constructor = Queue
    queue.id = id
    queue.key = "#{namespace}:queue:#{id}"
    queue.create = (id) ->
        "__proto__": queue.prototype
        "constructor": queue
        "id": id
        "key": "#{namespace}:result:#{id}"
    queue.prototype = {}

    Queue.call(queue, id)

    # register a redis worker for this queue; this listen on the redis queue
    # and will actually invoke `fn` when a message is posted, publishing the
    # results to any listeners
    workers.push(new Worker(queue, fn))

    # return the task constructor `queue`
    queue


module.exports = Task
