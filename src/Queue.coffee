"use strict"


class Queue
    # the metaclass of all task queues; distq(id, fn) returns instances of this
    # class, and invoking a queue will return an instance of it
    constructor: (id) ->
        @id = id


module.exports = Queue
