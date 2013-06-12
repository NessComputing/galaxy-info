logger = require './logger'
cli = require './cli'
config = require 'nconf'

WebServer = require './webserver'

###
The base application class.
###
class Application
  constructor: ->
    @ws = new WebServer()

  ###
  Aborts the application with a message.
  
  @param {String} (msg) The message to abort the application with
  ###
  abort: (msg) =>
    logger.info "Aborting application: #{msg}..."
    process.exit(1)

module.exports = Application
