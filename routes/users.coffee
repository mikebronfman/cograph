# routes/users.coffee
documents = require "./documents"
utils = require "./utils"

module.exports = (app, passport) ->
  
  # =====================================
  # HOME PAGE (with login links) ========
  # =====================================
  app.get "/", utils.isNotLoggedIn, (req, res) ->
    res.render "user-index.jade"
  
  # =====================================
  # LOGIN ===============================
  # =====================================
  # show the login form
  app.get "/login", (req, res) ->
    # render the page and pass in any flash data if it exists
    res.render "login.jade",
      message: req.flash("loginMessage")
  
  # process the login form
  app.post "/login", passport.authenticate("local-login",
    successRedirect: "/profile" # redirect to the secure profile section
    failureRedirect: "/login" # redirect back to the signup page if there is an error
    failureFlash: true # allow flash messages
  )
  
  # =====================================
  # SIGNUP ==============================
  # =====================================
  # show the signup form
  app.get "/signup", (req, res) ->
    # render the page and pass in any flash data if it exists
    res.render "signup.jade",
      message: req.flash("signupMessage")
  
  # process the signup form
  app.post "/signup", passport.authenticate("local-signup",
    successRedirect: "/profile" # redirect to the secure profile section
    failureRedirect: "/signup" # redirect back to the signup page if there is an error
    failureFlash: true # allow flash messages
  )
  
  # =====================================
  # PROFILE SECTION =====================
  # =====================================
  # we will want this protected so you have to be logged in to visit
  # we will use route middleware to verify this (the isLoggedIn function)
  app.get "/profile", utils.isLoggedIn, (req, res) ->
    documents.helper.getAll (docs) ->
      documents.helper.getByIds req.user.documents, (privateDocs) ->
        res.render "profile.jade",
          user: req.user # get the user out of session and pass to template
          docs: docs # prefetch the list of document names for opening
          userDocs: privateDocs # prefetch the users private documents
  
  # =====================================
  # LOGOUT ==============================
  # =====================================
  app.get "/logout", (req, res) ->
    req.logout()
    res.redirect "/"
