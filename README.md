# distq

A Node.JS Redis-backed distributed task queue with paranoia level over 9000.

## Install

```bash
npm install --save distq
```

## Usage

### Simple

```javascript
var task = require('distq');


var add = task('add', function(a, b, next) {
    next(null, a + b);
});


task(1, 2, function(err, result) {
    console.log(result);
});
```

### Promises

You could also use promises instead of `next` (either when calling, when
waiting for a response or both)

```javascript
var task = require('distq');


var add = task('add', function(a, b) {
    return a + b;
});


add(1, 2).then(result) {
    console.log(result);
});
```

### Custom redis settings

Creating a task will automatically connect to redis using the default settings.
However you can customize [redis](http://redis.js.org/#api-rediscreateclient)
parameters by using `distq.setup` before you register your first task:

```javascript
var task = require('distq');


task.setup({
    'host': '192.168.13.37', // could also be replaced with a single...
    'port': 1337,            // ... 'unix': '/var/run/redis.sock' argument
    'db': 666,               // you *probably* shouldn't have that many dbs
    'ns': 'distq:',          // change it if you you're worried about conflicts
    'options': {
        'parser': 'hiredis'  // or you know, whatever
    },
});


var add = task(...);
```
