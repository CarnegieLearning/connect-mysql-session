var Sequelize = require('sequelize');

module.exports = function (connect)
{
    function MySQLStore(database, user, password, options)
    {
        options = options || {};
        connect.session.Store.call(this, options);
        
        var self = this,
            forceSync = options.forceSync || false,
            checkExpirationInterval = options.checkExpirationInterval || 1000*60*10, // default 10 minutes.
            defaultExpiration = options.defaultExpiration || 1000*60*60*24; // default 1 day.
        
        var sequelize = new Sequelize(database, user, password, options);
        
        var Session = sequelize.define('Session', {
            sid: {type: Sequelize.STRING, unique: true, allowNull: false},
            expires: Sequelize.INTEGER,
            json: Sequelize.TEXT
        });
        
        var initialized = false;
        
        function initialize(callback)
        {
            if (initialized) callback();
            else
            {
                sequelize.sync({force: forceSync})
                .on('success', function ()
                {
                    console.log('MySQL session store initialized.');
                    initialized = true;
                    callback();
                })
                .on('failure', function (error)
                {
                    console.log('Failed to initialize MySQL session store:');
                    console.log(error);
                    callback(error);
                });
            }
        }
        
        // Check periodically to clear out expired sessions.
        setInterval(function ()
        {
            initialize(function (error)
            {
                if (error) return;
                Session.findAll({where: ['expires < ?', Math.round(Date.now() / 1000)]})
                .on('success', function (sessions)
                {
                    if (sessions.length > 0)
                    {
                        console.log('Destroying ' + sessions.length + ' expired sessions.');
                        for (var i in sessions)
                        {
                            sessions[i].destroy();
                        }
                    }
                })
                .on('failure', function (error)
                {
                    console.log('Failed to fetch expired sessions:');
                    console.log(error);
                });
            });
        }, checkExpirationInterval);
        
        this.get = function (sid, fn)
        {
            initialize(function (error)
            {
                if (error) return fn(error, null);
                Session.find({where: {sid: sid}})
                .on('success', function (record)
                {
                    var session = record && JSON.parse(record.json);
                    fn(null, session);
                })
                .on('failure', function (error)
                {
                    fn(error, null);
                });
            });
        };
        
        this.set = function (sid, session, fn)
        {
            initialize(function (error)
            {
                if (error) return fn && fn(error);
                Session.find({where: {sid: sid}})
                .on('success', function (record)
                {
                    if (!record)
                    {
                        record = Session.build({sid: sid});
                    }
                    record.json = JSON.stringify(session);
                    
                    // Set expiration to match the cookie or 1 year in the future if unspecified.
                    var expires = session.cookie.expires ||
                                  new Date(Date.now() + defaultExpiration);
                    // Note: JS uses milliseconds, but we want integer seconds.
                    record.expires = Math.round(expires.getTime() / 1000);
                    
                    record.save()
                    .on('success', function ()
                    {
                        fn && fn();
                    })
                    .on('failure', function (error)
                    {
                        fn && fn(error);
                    });
                })
                .on('failure', function (error)
                {
                    fn && fn(error);
                });
            });
        };
        
        this.destroy = function (sid, fn)
        {
            initialize(function (error)
            {
                if (error) return fn && fn(error);
                Session.find({where: {sid: sid}})
                .on('success', function (record)
                {
                    if (record)
                    {
                        record.destroy()
                        .on('success', function ()
                        {
                            fn && fn();
                        })
                        .on('failure', function (error)
                        {
                            console.log('Session ' + sid + ' could not be destroyed:');
                            console.log(error);
                            fn && fn(error);
                        });
                    }
                    else fn && fn();
                })
                .on('failure', function (error)
                {
                    fn && fn(error);
                });
            });
        };
        
        this.length = function (callback)
        {
            initialize(function (error)
            {
                if (error) return callback(null);
                Session.count()
                .on('success', callback)
                .on('failure', function () { callback(null); });
            });
        };
        
        this.clear = function (callback)
        {
            sequelize.sync({force: true}, callback);
        };
    }
    
    MySQLStore.prototype.__proto__ = connect.session.Store.prototype;
    
    return MySQLStore;
};
