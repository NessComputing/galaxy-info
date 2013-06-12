express = require 'express'
http = require 'http'

config = require 'nconf'
logger = require './logger'

routes = require './routes'
GalaxyInfo = require './galaxy-info'

errorHandler = (err, req, res, next) ->
  res.json 500, error: err

###
The webserver class.
###
class WebServer
  constructor: ->
    @app = express()
    @app.use(express.methodOverride())
    @app.use(express.bodyParser())
    @app.use(express.favicon())
    @app.use(@app.router)
    @app.use(errorHandler)
    @app.locals.gi = new GalaxyInfo()

    @setup_routing()
    @srv = http.createServer(@app)
    @srv.listen(config.get('port'))
    logger.info "Webserver is up at: http://0.0.0.0:#{config.get('port')}"

  # Sets up the webserver routing.
  setup_routing: =>
    @app.get '/', routes.version
    @app.get '/version', routes.version

    @app.get '/clear', routes.galaxy.clear
    @app.get '/show', routes.galaxy.showall
    @app.get '/show/:slot', routes.galaxy.show
    @app.get '/status/:slot', routes.galaxy.status

    @app.post '/update', routes.galaxy.update

module.exports = WebServer
