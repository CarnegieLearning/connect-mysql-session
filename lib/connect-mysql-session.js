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
            sid: Sequelize.STRING,
            expires: Sequelize.INTEGER,
            json: Sequelize.TEXT
        });
        
        sequelize.sync({force: forceSync})
        .on('failure', function (error)
        {
            console.log(error);
        });
        
        // Check periodically to clear out expired sessions.
        setInterval(function ()
        {
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
        }, checkExpirationInterval);
        
        this.get = function (sid, fn)
        {
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
        };
        
        this.set = function (sid, session, fn)
        {
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
        };
        
        this.destroy = function (sid, fn)
        {
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
        };
        
        this.length = function (callback)
        {
            Session.count()
            .on('success', callback)
            .on('failure', function () { callback(null); });
        };
        
        this.clear = function (callback)
        {
            sequelize.sync({force: true});
        };
    }
    
    MySQLStore.prototype.__proto__ = connect.session.Store.prototype;
    
    return MySQLStore;
};
