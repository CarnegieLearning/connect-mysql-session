Sequelize = require("sequelize")
module.exports = (connect) ->
  MySQLStore = (database, user, password, options) ->
    # default 10 minutes.
    # default 1 day.
    initialize = (callback) ->
      unless initialized
        sequelize.sync(force: forceSync).on("success", ->
          console.log "MySQL session store initialized."
          initialized = true
          callback()
        ).on "failure", (error) ->
          console.log "Failed to initialize MySQL session store:"
          console.log error
          callback error

    options = options or {}
    connect.session.Store.call this, options
    self = this
    forceSync = options.forceSync or false
    checkExpirationInterval = options.checkExpirationInterval or 1000 * 60 * 10
    defaultExpiration = options.defaultExpiration or 1000 * 60 * 60 * 24
    sequelize = new Sequelize(database, user, password, options)
    Session = sequelize.define("Session",
      sid:
        type: Sequelize.STRING
        unique: true
        allowNull: false

      expires: Sequelize.INTEGER
      json: Sequelize.TEXT
    )
    initialized = false
    
    # Check periodically to clear out expired sessions.
    setInterval (->
      initialize (error) ->
        return  if error
        Session.findAll(where: ["expires < ?", Math.round(Date.now() / 1000)]).on("success", (sessions) ->
          if sessions.length > 0
            console.log "Destroying " + sessions.length + " expired sessions."
            for i of sessions
              sessions[i].destroy()
        ).on "failure", (error) ->
          console.log "Failed to fetch expired sessions:"
          console.log error


    ), checkExpirationInterval
    @get = (sid, fn) ->
      initialize (error) ->
        return fn(error, null)  if error
        Session.find(where:
          sid: sid
        ).on("success", (record) ->
          session = record and JSON.parse(record.json)
          fn null, session
        ).on "failure", (error) ->
          fn error, null



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



    @destroy = (sid, fn) ->
      initialize (error) ->
        return fn and fn(error)  if error
        Session.find(where:
          sid: sid
        ).on("success", (record) ->
          if record
            record.destroy().on("success", ->
              fn and fn()
            ).on "failure", (error) ->
              console.log "Session " + sid + " could not be destroyed:"
              console.log error
              fn and fn(error)

          else
            fn and fn()
        ).on "failure", (error) ->
          fn and fn(error)



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