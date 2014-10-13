// config/passport.js

// load all the things we need
var LocalStrategy   = require('passport-local').Strategy;
var FacebookStrategy = require('passport-facebook').Strategy;
var TwitterStrategy = require('passport-twitter').Strategy;
var _ = require(__dirname + '/../node_modules/underscore/underscore');

// load up the user model
var User = require('../models/user.coffee');

// reserved usernames
// these cannot be used as usernames since they will interfere with other routes
var usernameBlacklist = ['login', 'logout', 'document', 'signup', 'profile', 'landing', 'new', 'mobile', 'errors'];
var userNameRegEx = /^(\w+)$/;

// expose this function to our app using module.exports
module.exports = function(passport) {

    // =========================================================================
    // passport session setup ==================================================
    // =========================================================================
    // required for persistent login sessions
    // passport needs ability to serialize and unserialize users out of session

    // used to serialize the user for the session
    passport.serializeUser(function(user, done) {
        done(null, user.id);
    });

    // used to deserialize the user
    passport.deserializeUser(function(id, done) {
        User.findById(id, function(err, user) {
            done(err, user);
        });
    });

    // // #TODO
    // // Facebook signup
    // passport.use(new FacebookStrategy({
    //     clientID: "315770905267996",
    //     clientSecret: "c8dbadb98d4275b64a13198b8f7df7f6",
    //     callbackURL: "http://thecograph.com/auth/facebook/callback"
    //   },
    //   function(accessToken, refreshToken, profile, done) {
    //     User.findOrCreate({ 'local.facebook.id': profile.id }, function(err, user) {
    //       if (err) { return done(err); }
    //       done(null, user);
    //     });
    //   }
    // ));

    // Twitter Signup
    passport.use(new TwitterStrategy({
        consumerKey: "iRnrLu6QrYHPlOF0wq2ns1MYl",
        consumerSecret: "bdIQkb16hSVAvr64sTkq0YXhyysBoZ5dvMQSM9d3tdsCz3JdNx",
        callbackURL: "http://127.0.0.1:3000/auth/twitter/callback"
      },
      function(token, tokenSecret, profile, done) {
        process.nextTick(function() {
            User.findOne({ 'twitter.id': profile.id }, function(err, user) {
                if (err)
                    return done(err);
                    // check to see if theres already a user with that name
                User.findOne({ 'local.nameLower' : profile.username.toLowerCase() }, function(err, namedUser) {
                    // if there are any errors, return the error
                    if (err)
                        return done(err);
                    // check to see if theres already a user with that name
                    if (namedUser || _.contains(usernameBlacklist, profile.username)) {
                        if(namedUser.local.twitter.id == profile.id)
                            // LOGIN
                            console.log('login')
                        else // username taken
                            return done(err);
                    }
                    else {
                        // create the user
                        var newUser            = new User();
                        // set the user's local credentials
                        newUser.local.email     = profile.email;
                        newUser.local.name      = profile.username;
                        newUser.local.nameLower = profile.username.toLowerCase();
                        newUser.local.twitter   = profile._json
                        // save the user
                        newUser.save(function(err) {
                          if (err)
                              throw err;
                          return done(null, newUser);
                        });
                    }
                });
            });
        });
      }
    ));

    // =========================================================================
    // LOCAL SIGNUP ============================================================
    // =========================================================================
    // we are using named strategies since we have one for login and one for signup
    // by default, if there was no name, it would just be called 'local'

    passport.use('local-signup', new LocalStrategy({
        // by default, local strategy uses username and password, we will override with email
        usernameField : 'email',
        passwordField : 'password',
        nameField     : 'name',
        passReqToCallback : true // allows us to pass back the entire request to the callback
    },
    function(req, email, password, done) {

        // asynchronous
        // User.findOne wont fire unless data is sent back
        process.nextTick(function() {

            // find a user whose email is the same as the forms email
            // we are checking to see if the user trying to login already exists
            User.findOne({ 'local.email' :  email }, function(err, user) {
                // if there are any errors, return the error
                if (err)
                    return done(err);

                // check to see if theres already a user with that email
                if (user) {
                    return done(null, false, req.flash('signupMessage', 'That email is already taken.'));
                }
                if (!userNameRegEx.test(req.body.name)) {
                    return done(null, false, req.flash('signupMessage', 'You must choose a username (with only letters and numbers).'));
                }
                else {
                    // if there is no user with that email
                    // check to see if the username is available
                    User.findOne({ 'local.nameLower' :  req.body.name.toLowerCase() }, function(err, namedUser) {
                        // if there are any errors, return the error
                        if (err)
                            return done(err);
                        // check to see if theres already a user with that name
                        if (namedUser || _.contains(usernameBlacklist, req.body.name)) {
                            return done(null, false, req.flash('signupMessage', 'That username is already taken.'));
                        }
                        else {
                            // create the user
                            var newUser            = new User();

                            // set the user's local credentials
                            newUser.local.email     = email;
                            newUser.local.name      = req.body.name;
                            newUser.local.nameLower = newUser.local.name.toLowerCase();
                            newUser.local.password  = newUser.generateHash(password);
                            newUser.local.twitter   = {}
                    // save the user
                            newUser.save(function(err) {
                                if (err)
                                    throw err;
                                return done(null, newUser);
                            });
                        }
                    });
                }

            });  

        });

    }));

    // =========================================================================
    // LOCAL LOGIN =============================================================
    // =========================================================================
    // we are using named strategies since we have one for login and one for signup
    // by default, if there was no name, it would just be called 'local'

    passport.use('local-login', new LocalStrategy({
        // by default, local strategy uses username and password, we will override with email
        usernameField : 'email',
        passwordField : 'password',
        passReqToCallback : true // allows us to pass back the entire request to the callback
    },
    function(req, email, password, done) { // callback with email and password from our form

        // find a user whose email is the same as the forms email
        // we are checking to see if the user trying to login already exists
        User.findOne({ 'local.email' :  email }, function(err, user) {
            // if there are any errors, return the error before anything else
            if (err)
                return done(err);

            // if no user is found, return the message
            if (!user)
                return done(null, false, req.flash('loginMessage', 'No user found.')); // req.flash is the way to set flashdata using connect-flash

            // if the user is found but the password is wrong
            if (!user.validPassword(password))
                return done(null, false, req.flash('loginMessage', 'Oops! Wrong password.')); // create the loginMessage and save it to session as flashdata

            // all is well, return successful user
            return done(null, user);
        });

    }));

};