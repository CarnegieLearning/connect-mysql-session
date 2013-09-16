connect-mysql-session
=====================

A MySQL session store for the [connectjs][] [session middleware][] for [node.js][].

An highly optimized dependency-reduced version of original work by "CarnegieLearning".

Optimizations/Deltas
--------------------
* Now written (and maintained) in Coffeescript
* Removed unnecessary dependence on Sequelize
* Forward support for mySql's in-memory database engine

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


### Better performance?

Sessions are the simplest case of table storage using no relations and single primary key btree or hash indexes. This largely mitigates the disadvantages of relational database overhead (conversely mitigating most of the advantages of dictionary stores that are essentially the same thing as flat tables with single indexes).

By default this library uses the InnoDB persistent storage engine in MySQL to allow for up to 16MB of data to be stored in each user session and to do so with dynamic memory allocation. InnoDB is only about 2%-8% slower than a similarly provisioned Redis instance.

If greater performance is desired, you can switch to the MySQL Memory engine with a one word change to the code (will eventually be a direct config option in this library). MySQL in-memory table stores are about as efficient as data storage can get, primary due to its lack of features. The entire table is statically allocated with data allocated in small blocks within it and indexed with a hash or binary tree.

As [this study](http://bit.ly/17ZzafB) revealed,

MySQL's Memory Engine performed sustained writes at 92% the speed of Redis, yet performed reads at almost 25X (times!!!) the speed. Given that session stores show a heavy read bias, the end result is a large performance gain.

Limitations
-----------

### General

These limitations apply regardless of the database engine chosen:

* MySQL version >= 5.0.3 with Memory Engine is required
* Node.js version >= 0.8
* Session data must be JSON serializable (no binary objects)

### Memory Engine

In general, if you follow best-practices for session storage you won't have problems, but MySQL's memory engine gains performance through limiting what and how you can store data.

* Maximum serialized session size is 20k bytes (MySQL Memory Engine restriction resulting from row-size limit)
* Memory allocated to the engine is not available to cache primary tables and can hurt performance if too large.

### InnoDB Engine

If you use the InnoDB engine (default):

* Maximum serialized session size is 16MB bytes
  

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
        store: new MySQLSessionStore({
            host: 127.0.0.1, //database host name
            user: "root", //database username
            password: "", //database user's password
            checkExpirationInterval: 12*60*60, //how frequently to check for dead sessions (seconds)
            defaultExpiration: 7*24*60*60 //how long to keep session alive (seconds)
        }),
        secret: "keyboard cat"
    }));
    ...

Options
-------

### host, user, password ###

Database credentials. Defaults to localhost defaults.

### checkExpirationInterval ###

Default: `12*60*60` (Twice a day). Specified in seconds. How frequently the session store checks for and clears expired sessions.

### defaultExpiration ###

Default: `7*24*60*60` (1 week). Specified in seconds. How long session data is stored for "user session" cookies -- i.e. sessions that only last as long as the user keeps their browser open, which are created by doing `req.session.maxAge = null`.

Changes
-------

### 0.2.6 (2013-09-14)

* Switch to Coffeescript
* Removed Sequelize
* Built on InnoDB engine (MUCH more space performant)
* Built on memory engine (MUCH more time performant)

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
