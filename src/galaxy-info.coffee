{exec} = require 'child_process'
os = require 'os'
fs = require 'fs'

config = require 'nconf'
logger = require './logger'
request = require 'request'
_ = require 'lodash'

###
The Galaxy Info cache.
###
class GalaxyInfo
  constructor: ->
    @agents = []
    @health = {}

    @configuration = {}
    @monitoring_lookups = {}
    @jmx_lookups = {}

    @has_service = false
    @update_timer = null
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
        @update_timer = setInterval () =>
          @update_galaxyinfo()
        , 15000

  ###
  Updates the local cache with the most recent data.
  ###
  update_galaxyinfo: =>
    unless @has_service then return
    exec "galaxy -m #{os.hostname()} show-json", (err, stdout, stderr) =>
      if err then logger.warn "Error running galaxy show"
      else
        logger.info "updating galaxy info"
        try
          @agents = JSON.parse(stdout).agents
          @register_jolosrv_services()
        catch error
          logger.warn "Unable to parse galaxy show-json output"

  ###
  Clears the slot info and reloads config.
  ###
  clear: =>
    @update_timer = null
    @agents = []
    @reload_configuration()
    @update_galaxyinfo()

  ###
  Reads the galaxy-info configuration file and sets up svc mappings.
  ###
  reload_configuration: =>
    try
      @configuration = JSON.parse(
        fs.readFileSync(config.get('config')).toString())
      @monitoring_lookups = @configuration.services
      @jmx_lookups = JSON.parse(
        fs.readFileSync(@configuration.mapping).toString())
        )
    catch error
      @monitoring_lookups = {}
      @jmx_lookups = {}
      logger.error "Error reading configuration file: #{error}"

  ###
  The list of client id's.
  ###
  client_list: =>
    @agents.map (agent) -> agent.id

  ###
  The list of http monitorable clients.
  ###
  http_clients: =>
    @agents
    .filter((agent) -> agent.type != null)
    .map (agent) -> agent.id

  ###
  The list of jmx supported clients.
  ###
  jmx_clients: =>
    @agents
    .filter((agent) ->
      agent.type != null and not (
        @jmx_clients[agent.formal_type] == null or
        @jmx_clients[agent.format_type] == undefined)
    .map (agent) -> agent.id

  ###
  Updates the current jolosrv client list with the existing agents.
  ###
  register_jolosrv_services: =>
    request.get 'http://localhost:3014/clients', json: true,
    timeout: 5000, (error, response, body) =>
      if error then logger.error error
      else
        _.difference(@jmx_clients(), body.clients)
        _.difference(body.clients, @jmx_clients())

module.exports = GalaxyInfo
