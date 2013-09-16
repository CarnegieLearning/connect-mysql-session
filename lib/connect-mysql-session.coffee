mysql = require "mysql"

module.exports = (connect) ->
  
  ###
    options =
      host: name of the database's host
      user: login username
      password: login password
      checkExpirationInterval: (in seconds)
      defaultExpiration: (in seconds)
      client: (optional) fully instantiated client to use, instead of creating one internally      
  ###

  class MySqlStore extends connect.session.Store
    constructor: (@options) ->
      # -- Context
      @initialized = false
      # -- Default values    
      @options = @options or {}
      @options.host ?= "127.0.0.1"
      @options.user ?= "root"
      @options.password ?= ""
      @options.checkExpirationInterval ?= 12*60*60 #check twice a day
      @options.defaultExpiration ?= 7*24*60*60 #expire after one week
      # -- Link middleware
      connect.session.Store.call this, @options
      # -- Create client
      @client = options.client or mysql.createConnection @options    
      @client.on "error", =>
        @emit "disconnect"
      @client.on "connect", =>
        @emit "connect"

    initialize: (fn) =>
      return fn() if @initialized #run only once
      @client.connect()
      sql = """
        CREATE DATABASE IF NOT EXISTS `sessions`
      """
      @client.query sql, (err, rows, fields) =>
        if err?
          console.log "Failed to initialize MySQL session store. Couldn't create sessions database.", err
          return fn err
        sql = """
          CREATE TABLE IF NOT EXISTS `sessions`.`session` (
            `sid` varchar(40) NOT NULL DEFAULT '',
            `ttl` int(11) DEFAULT NULL,
            `json` mediumtext DEFAULT NULL,
            `createdAt` datetime DEFAULT NULL,
            `updatedAt` datetime DEFAULT NULL,
            PRIMARY KEY (`sid`)
          ) 
          ENGINE=INNODB 
          DEFAULT CHARSET=utf8
        """
        @client.query sql, (err, rows, fields) =>
          if err?
            console.log "Failed to initialize MySQL session store. Couldn't create session table.", err
            return fn err
          console.log "MySQL session store initialized."
          @initialized = true
          @_watchdog() #expire expired sessions
          fn()

    _watchdog: () =>      
      sql = """
        DELETE FROM `sessions`.`session` WHERE TIME_TO_SEC(UTC_TIMESTAMP()) - TIME_TO_SEC(`updatedAt`) > `ttl`
      """
      @client.query sql, [], (err, meta) =>
        console.log "Could not cleanup expired sessions:", err if err?
        console.log "Removed #{meta.affectedRows} expired user sessions." if meta.affectedRows > 0
        setTimeout @_watchdog, @options.checkExpirationInterval * 1000


    get: (sid, fn) =>
      @initialize (error) =>
        return fn error if error?
        @client.query "SELECT * FROM `sessions`.`session` WHERE `sid`=?", [sid], (err, rows, fields) =>
          return fn err if err?
          result = undefined
          try            
            result = JSON.parse rows[0].json if rows?[0]?
          catch err
            return fn err
          fn undefined, result


    set: (sid, session, fn) =>      
      maxAge = session.cookie.maxAge
      ttl = @options.ttl
      json = JSON.stringify(session)
      ttl = ttl or ((if "number" is typeof maxAge then maxAge / 1000 | 0 else @options.defaultExpiration))
      @initialize (error) =>
        return fn error if error?        
        # -- Update session if exists; Create otherwise        
        sql = """
          INSERT INTO `sessions`.`session` (`sid`, `ttl`, `json`, `createdAt`, `updatedAt`) 
          VALUES (?, ?, ?, UTC_TIMESTAMP(), UTC_TIMESTAMP())
          ON DUPLICATE KEY 
          UPDATE `ttl`=?, `json`=?, `updatedAt`=UTC_TIMESTAMP()
        """
        @client.query sql, [sid, ttl, json, ttl, json], (err) =>
          return fn err if err?
          fn.apply(this, arguments)


    destroy: (sid, fn) =>
      @initialize (error) =>
        return fn error if error?
        @client.query "DELETE FROM `sessions`.`session` WHERE `sid`=?",[sid], (err, rows, fields) ->
          if err?
            console.log "Session " + sid + " could not be destroyed."
            return fn err, undefined 
          fn()

  return MySqlStore