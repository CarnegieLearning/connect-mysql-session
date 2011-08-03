connect-mysql-session
=====================

A MySQL session store for the [connectjs][] [session middleware][] for [node.js][].

Currently, this code appears to function correctly but it has not been optimized for performance.  The store is implemented using [sequelize][] ORM, simply dumping the JSON-serialized session into a MySQL TEXT column.

Installation
------------

Using [npm][]:

    npm install -g connect-mysql-session

By cloning the repo:

    git clone git://github.com/CarnegieLearning/connect-mysql-session.git
    cd connect-mysql-session
    npm link

(Note: in both cases you may need to use `sudo` when performing the `npm` step.)

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
