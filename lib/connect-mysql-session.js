var Sequelize = require('sequelize');

module.exports = function (connect)
{
    function MySQLStore(database, user, password, options)
    {
        var self = this;
        options = options || {};
        connect.session.Store.call(this, options);
        
        var sequelize = new Sequelize(database, user, password, options);
        var Session = sequelize.define('Session', {
            sid: Sequelize.STRING,
            expires: Sequelize.DATE,
            json: Sequelize.TEXT
        });
        
        sequelize.sync()
        .on('failure', function (error)
        {
            console.log(error);
        });
        
        // Check once a minute for expired sessions.
        setInterval(function ()
        {
            Session.findAll({where: ['expires < ?', new Date()]}).on('success', function (sessions)
            {
                console.log('Destroying ' + sessions.length + ' expired sessions.');
                for (var i in sessions)
                {
                    sessions[i].destroy();
                }
            })
            .on('failure', function (error)
            {
                console.log('Failed to fetch expired sessions:');
                console.log(error);
            });
        }, 60000);
        
        this.get = function (sid, fn)
        {
            Session.find({where: {sid: sid}}).on('success', function (record)
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
            Session.find({where: {sid: sid}}).on('success', function (record)
            {
                if (record)
                {
                    clearTimeout(record.expirationTimeoutID);
                }
                else
                {
                    record = Session.build({sid: sid});
                }
                record.json = JSON.stringify(session);
                record.expires = session.cookie.expires || new Date('2050-12-31 23:59:59');
                
                record.save().on('success', function ()
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
            self.get(sid, function (error, record)
            {
                if (error) return fn && fn(error);
                if (record)
                {
                    record.destroy().on('success', function ()
                    {
                        console.log('Session ' + sid + ' has been destroyed.');
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
