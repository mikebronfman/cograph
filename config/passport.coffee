# config/passport.js

# load all the things we need
LocalStrategy = require('passport-local').Strategy
TwitterStrategy = require('passport-twitter').Strategy
_ = require(__dirname + '/../node_modules/underscore/underscore')

# These are needed to import tweets into a new cograph
url = process.env['GRAPHENEDB_URL'] or 'http://localhost:7474'
neo4j = require(__dirname + '/../node_modules/neo4j')
graphDb = new (neo4j.GraphDatabase)(url)
DocumentHelper = require(__dirname + '/../routes/helpers/DocumentHelper')
serverDocument = new DocumentHelper(graphDb)

# load up the user model
User = require('../models/user.coffee')

# reserved usernames
# these cannot be used as usernames since they will interfere with other routes
usernameBlacklist = [
  'login'
  'logout'
  'document'
  'signup'
  'profile'
  'landing'
  'new'
  'mobile'
  'errors'
  'forgot-password'
  'request-key'
  'forgotten-password'
  'about'
  'explore'
  'account'
  'auth'
]

userNameRegEx = /^(\w+)$/
Twit = require('twitter')

# expose this function to our app using module.exports
module.exports = (passport) ->
  # =========================================================================
  # passport session setup ==================================================
  # =========================================================================
  # required for persistent login sessions
  # passport needs ability to serialize and unserialize users out of session
  # used to serialize the user for the session
  passport.serializeUser (user, done) ->
    done null, user.id

  # used to deserialize the user
  passport.deserializeUser (id, done) ->
    User.findById id, (err, user) ->
      done err, user

  # Twitter Signup
  #check if local
  if process.env.PORT
    cK = 'iRnrLu6QrYHPlOF0wq2ns1MYl'
    cS = 'bdIQkb16hSVAvr64sTkq0YXhyysBoZ5dvMQSM9d3tdsCz3JdNx'
    cbURL = 'http://www.cograph.co/auth/twitter/callback'
  else
    #local setup
    cK = 'kARoAoD1OPeDMmsNrVajrDdCm'
    cS = 'i027OrWxARTmn4UxRQPZJm1RXNGjnpw5hVSZnp39ULNFvjzkMc'
    cbURL = 'http://127.0.0.1:3000/auth/twitter/callback'

  passport.use new TwitterStrategy({
    consumerKey: cK
    consumerSecret: cS
    callbackURL: cbURL
  }, (token, tokenSecret, profile, done) ->
    process.nextTick ->
      User.findOne { 'twitter.id': profile.id }, (err, user) ->
        if err
          return done(err)
        # check to see if theres already a user with that name
        User.findOne { 'local.nameLower': profile.username.toLowerCase() }, (err, namedUser) ->
          # if there are any errors, return the error
          if err
            return done(err)
          # check to see if theres already a user with that name
          if namedUser or _.contains(usernameBlacklist, profile.username)
            if namedUser.twitter and namedUser.twitter.id == profile.id
              return done(null, user)
            else
              return done(null, false, message: 'Your twitter handle is taken. Please sign up using the form instead.')
          else
            # get the tweets
            OAuth = require('oauth')
            oauth = new (OAuth.OAuth)('https://api.twitter.com/oauth/request_token', 'https://api.twitter.com/oauth/access_token', cK, cS, '1.0A', null, 'HMAC-SHA1')
            oauth.get 'https://api.twitter.com/1.1/statuses/user_timeline.json?user_id='+profile.id+'&count=5', token, tokenSecret, (e, data, res) ->
              if e then console.error e
              # create the user
              newUser = new User
              # set the user's local credentials
              newUser.local.email = profile.email
              newUser.local.name = profile.username
              newUser.local.nameLower = profile.username.toLowerCase()
              newUser.twitter.id = profile.id
              newUser.twitter.username = profile.username
              newUser.twitter.displayName = profile.displayName
              newUser.twitter.tweets = data
              # parse the tweet data
              tweetData = JSON.parse(newUser.twitter.tweets)
              tweetTexts = (t.text for tweet in tweetData)

              # create the imported tweets document
              serverDocument.createTwitterCograph profile.username, newUser, tweetTexts, (savedDocument) ->
                # save the user
                newUser.save (err) ->
                  if err then throw err
                  # add the imported tweets document to the user
                  newUser.addDocument savedDocument._id
                  done null, newUser
  )

  # =========================================================================
  # LOCAL SIGNUP ============================================================
  # =========================================================================
  # we are using named strategies since we have one for login and one for signup
  # by default, if there was no name, it would just be called 'local'
  passport.use 'local-signup', new LocalStrategy({
    usernameField: 'email'
    passwordField: 'password'
    nameField: 'name'
    passReqToCallback: true
  }, (req, email, password, done) ->
    # asynchronous
    # User.findOne wont fire unless data is sent back
    process.nextTick ->
      # find a user whose email is the same as the forms email
      # we are checking to see if the user trying to login already exists
      User.findOne { 'local.email': email }, (err, user) ->
        # if there are any errors, return the error
        if err
          return done(err)
        # check to see if theres already a user with that email
        if user
          return done(null, false, req.flash('signupMessage', 'That email is being used by another account.'))
        if !userNameRegEx.test(req.body.name)
          return done(null, false, req.flash('signupMessage', 'You must choose a username (with only letters and numbers).'))
        else
          # if there is no user with that email
          # check to see if the username is available
          User.findOne { 'local.nameLower': req.body.name.toLowerCase() }, (err, namedUser) ->
            # if there are any errors, return the error
            if err
              return done(err)
            # check to see if theres already a user with that name
            if namedUser or _.contains(usernameBlacklist, req.body.name)
              return done(null, false, req.flash('signupMessage', 'That username is already taken.'))
            else
              # create the user
              newUser = new User
              # set the user's local credentials
              newUser.local.email = email
              newUser.local.name = req.body.name
              newUser.local.nameLower = newUser.local.name.toLowerCase()
              newUser.local.password = newUser.generateHash(password)
              newUser.local.twitter = {}
              # save the user
              newUser.save (err) ->
                if err then throw err
                done null, newUser
  )

  # =========================================================================
  # LOCAL LOGIN =============================================================
  # =========================================================================
  # we are using named strategies since we have one for login and one for signup
  # by default, if there was no name, it would just be called 'local'
  passport.use 'local-login', new LocalStrategy({
    usernameField: 'email'
    passwordField: 'password'
    passReqToCallback: true
  }, (req, email, password, done) ->
    # callback with email and password from our form
    # find a user whose email is the same as the forms email
    # we are checking to see if the user trying to login already exists
    User.findOne { 'local.email': email }, (err, user) ->
      # if there are any errors, return the error before anything else
      if err
        return done(err)
      # if no user is found, return the message
      if !user
        return done(null, false, req.flash('loginMessage', 'No user found.'))
      # req.flash is the way to set flashdata using connect-flash
      # if the user is found but the password is wrong
      if !user.validPassword(password)
        return done(null, false, req.flash('loginMessage', 'Oops! Wrong password.'))
      # create the loginMessage and save it to session as flashdata
      # all is well, return successful user
      done null, user
  )
