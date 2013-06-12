{exec} = require 'child_process'
os = require 'os'
fs = require 'fs'

config = require 'nconf'
logger = require './logger'

###
The Galaxy Info cache.
###
class GalaxyInfo
  constructor: ->
    @info = {}
    @svc_lookups = {}
    @has_service = false
    @initialize_updater()

  ###
  Begins the timer for galaxy updates.
  ###
  initialize_updater: =>
    warning = "`galaxy` cannot be found. Automatic updates will be disabled."
    exec 'which galaxy', (err, stdout, stderr) =>
      if err then logger.warn warning
      else
        @has_service = true
        setInterval () =>
          @update_galaxyinfo()
        , 30000

  ###
  Updates the local cache with the most recent data.
  ###
  update_galaxyinfo: =>
    unless @has_service then return
    exec "galaxy -m #{os.hostname()} show", (err, stdout, stderr) =>
      if err then logger.warn "Error running galaxy show"
      else
        logger.info "updating galaxy info"

  ###
  Clears the slot info and reloads config.
  ###
  clear: =>
    @info = {}
    @reload_configuration()
    @update_galaxyinfo()

  ###
  Reads the galaxy-info configuration file and sets up svc mappings.
  ###
  reload_configuration: =>
    try
      @svc_lookups = JSON.parse(
        fs.readFileSync(config.get('config')).toString()).services
    catch error
      logger.error "Error reading configuration file: #{error}"

module.exports = GalaxyInfo
