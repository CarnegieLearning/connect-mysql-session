mysql = require "mysql"

module.exports = (connect) ->
  
  ###
    connection = 
      host: name of the database's host
      user: login username
      password: login password
    options =
      checkExpirationInterval: (in minutes)
      defaultExpiration: (in minutes)
  ###
  MySQLStore = (_connection, _options) ->
    


    ###
      Default values
    ###
    _connection ?= {}
    _connection.host ?= "127.0.0.1"
    _connection.user ?= "root"
    _connection.password ?= ""
    connection = mysql.createConnection _connection
    _options ?= {}
    _options.checkExpirationInterval ?= 24*60 #check once a day
    _options.defaultExpiration ?= 7*24*60 #expire after one week
    options = _options



    ###
      Connect & Initialize MySQL Engine
    ###
    initialize = (callback) ->
      unless initialized
        connection.connect()
        sql = """
          CREATE DATABASE IF NOT EXISTS `sessions`
        """
        connection.query sql, (err, rows, fields) ->
          if err?
            console.log "Failed to initialize MySQL session store. Couldn't create sessions database.", err
            callback err; return      
          sql = """
            CREATE TABLE IF NOT EXISTS `sessions`.`session` (
              `sid` varchar(40) NOT NULL DEFAULT '',
              `expires` int(11) DEFAULT NULL,
              `json` varchar(4096) DEFAULT '',
              PRIMARY KEY (`sid`)
            ) 
            ENGINE=MEMORY 
            DEFAULT CHARSET=utf8
          """
          connection.query sql, (err, rows, fields) ->
            if err?
              console.log "Failed to initialize MySQL session store. Couldn't create session table.", err
              callback err; return      
            console.log "MySQL session store initialized."
            initialized = true
            callback()

    connect.session.Store.call this, options
    self = this
    initialized = false
    


    ###
      Check periodically to clear out expired sessions.
    ###
    setInterval (->
      initialize (error) ->
        return if error
        sql = """
          DELETE FROM `sessions`.`SESSION` WHERE expires < ? 
        """
        connection.query sql, [Math.round(Date.now() / 1000)], (err, rows, fields) ->
          if err?
            console.log "Failed to fetch expired sessions:", err
            return
          console.log "Destroying " + rows.length + " expired sessions."    
    ), checkExpirationInterval



    ###
      Retrieve the session data
    ###
    @get = (sid, fn) ->
      initialize (error) ->
        return fn(error, null) if error?
        connection.query "SELECT * FROM `sessions`.`session` WHERE `sid`=?",[sid], (err, rows, fields) ->
          if err?
            fn err, undefined 
            return
          fn undefined, JSON.parse(rows[0].json)


    ###
      Write to the user session
    ###
    @set = (sid, session, fn) ->
      initialize (error) ->
        return fn and fn(error)  if error
        
        # Set expiration to match the cookie or 1 year in the future if unspecified.
        
        # Note: JS uses milliseconds, but we want integer seconds.
        Session.find(where:
          sid: sid
        ).on("success", (record) ->
          record = Session.build(sid: sid)  unless record
          record.json = JSON.stringify(session)
          expires = session.cookie.expires or new Date(Date.now() + defaultExpiration)
          record.expires = Math.round(expires.getTime() / 1000)
          record.save().on("success", ->
            fn and fn()
          ).on "failure", (error) ->
            fn and fn(error)

        ).on "failure", (error) ->
          fn and fn(error)



    ###
      Delete the user session
    ###
    @destroy = (sid, fn) ->
      initialize (error) ->
        return fn(error, null) if error?
        connection.query "DELETE FROM `sessions`.`session` WHERE `sid`=?",[sid], (err, rows, fields) ->
          if err?
            console.log "Session " + sid + " could not be destroyed."
            fn err, undefined 
            return
          fn()



    @length = (callback) ->
      initialize (error) ->
        return callback(null)  if error
        Session.count().on("success", callback).on "failure", ->
          callback null



    @clear = (callback) ->
      sequelize.sync
        force: true
      , callback
  MySQLStore::__proto__ = connect.session.Store::
  MySQLStore