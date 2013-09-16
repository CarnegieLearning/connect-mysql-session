connect-mysql-session
=====================

A MySQL session store for the [connectjs][] [session middleware][] for [node.js][].

An highly optimized dependency-reduced version of original work by "CarnegieLearning".

Optimizations/Deltas
--------------------
* Now written (and maintained) in Coffeescript
* Removed unnecessary dependence on Sequelize
* Switched to mySql's in-memory database engine

Why MySQL for Sessions?
------------------------

### Less Maintenance

* If you already use MySQL for your primary data store, eliminating the use of Mongo or Redis reduces the number of vendors, number of critical failure points, and probability of failure in your system as a whole.

* Reduced polyglot results from eliminating yet another domain specific language (Redis/Mongo) from your development stack.

* You don't have to build/configure additional monitoring and management for your session store. Your primary data store automatically covers it.

* Upgrades to your primary datastore automatically effect the session store. You don't need to perform two separate upgrades.

### Lower Operating Costs

* It is less expensive to scale existing technology (provision a larger database server), than to provision multiple smaller database servers

* Fewer servers makes it less expensive to run staging and development copies of your infrastructure.

* Fewer languages means less development time and fewer management and monitoring tools to buy. You are already monitoring your primary data store, why not just reuse that investment.


### Better performance

MySQL in-memory table stores are about as efficient as data storage can get, primary due to its lack of features. Data is allocated in small blocks and indexed with a hash or binary tree.

As [this study](http://www.aspieschool.com/wiki/index.php?title=Redis_vs_MySQL_(Benchmarks)) revealed,

MySQL's Memory Engine can performed sustained writes at 92% the speed of Redis, yet performs reads at almost 25X (times!!!) faster. Given that session stores show a heavy read bias, the end result is a large performance gain.

Limitations
-----------

In general, if you follow best-practices for session storage you won't have problems, but MySQL's memory engine gains performance through limiting what and how you can store data.

* Session data must be JSON serializable (no binary objects)
* Maximum serialized session size is 4096 bytes (chosen for practicality/performance; hard coded, not MySQL restriction)

Installation
------------

Usage
-----

The following example uses [expressjs][], but this should work fine using [connectjs][] without the [expressjs][] web app layer.

    var express = require('express'),
        MySQLSessionStore = require('connect-mysql-session')(express);

    var app = express.createServer();
    app.use(express.cookieParser());
    app.use(express.session({
        store: new MySQLSessionStore("dbname", "user", "password", {
            // options...
        }),
        secret: "keyboard cat"
    }));
    ...

Options
-------

### forceSync ###

Default: `false`. If set to true, the Sessions table will be dropped before being reinitialized, effectively clearing all session data.

### checkExpirationInterval ###

Default: `1000*60*10` (10 minutes). How frequently the session store checks for and clears expired sessions.

### defaultExpiration ###

Default: `1000*60*60*24` (1 day). How long session data is stored for "user session" cookies -- i.e. sessions that only last as long as the user keeps their browser open, which are created by doing `req.session.maxAge = null`.

Changes
-------

### 0.2.0 (2013-09-14)

* Switch to Coffeescript
* Removed Sequelize
* Built on memory engine (MUCH more performant)

### 0.1.1 and 0.1.2 (2011-08-03) ###

* Lazy initialization to ensure model is ready before accessing.
* Index the sid column.

### 0.1.0 (2011-07-19) ###

* Initial version.


[connectjs]: http://senchalabs.github.com/connect/
[session middleware]: http://senchalabs.github.com/connect/middleware-session.html
[node.js]: http://nodejs.org/
[sequelize]: http://www.sequelizejs.com/
[expressjs]: http://expressjs.com/
[npm]: http://npmjs.org/
