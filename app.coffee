# Set up ============================================================
# loads all the tools we'll need
express = require 'express.io'
path = require 'path'
mongoose = require 'mongoose'
passport = require 'passport'
flash = require 'connect-flash'
compression = require 'compression'

morgan = require 'morgan'
cookieParser = require 'cookie-parser'
session = require 'express-session'
favicon = require 'static-favicon'
bodyParser = require 'body-parser'
RedisStore = require('connect-redis')(session)

configDB = require './config/database.js'

app = express()

# configuration ======================================================
mongoose.connect configDB.url # connect to our user database


require('./models/beta-requests.coffee')
require('./config/passport')(passport) # pass passport for configuration

# set up express app =================================================
app.set 'views', __dirname + '/app/public'
app.set 'view engine', 'jade'

app.use compression() #uses expressjs/compression on all requests

app.use morgan('dev')
app.use cookieParser()
app.use favicon(path.join(__dirname, '/app/assets/images/favicon.ico'))
app.use require('less-middleware')(path.join(__dirname, '/app/') )
app.use bodyParser()

# setup redis for passport
redis = require('redis')
url = require('url')
redisURL = url.parse(process.env.REDISCLOUD_URL || 'redis://rediscloud:oadtPM2ikltqQurz@pub-redis-14154.us-east-1-3.1.ec2.garantiadata.com:14154')
clientRedis = redis.createClient(redisURL.port, redisURL.hostname, {no_ready_check: true})
clientRedis.auth(redisURL.auth.split(":")[1]);

app.use session
  secret: 'gdocsisthebestgdocsisthebest' # session secret
  store : new RedisStore
    client: clientRedis
    ttl: 6048000 # ten weeks
  cookie :
    maxAge : 6048000 # ten weeks

app.use passport.initialize()
app.use passport.session() # persistent login sessions
app.use flash() # use connect-flash for flash messages stored in session

# this line must be after the less-middleware declaration
# http://stackoverflow.com/questions/19489681/node-js-less-middleware-not-auto-compiling
app.use express.static(path.join(__dirname, '/app'))

# routes =============================================================
# user routes
# load our routes and pass in our app and fully configured passport
require('./routes/users.coffee')(app, passport)

routes = require './routes/index'
app.use '/', routes

# set up real time routes
sockets = require './routes/sockets'
sockets.socketServer(app)

module.exports = app
