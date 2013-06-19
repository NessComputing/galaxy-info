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
    @j_url = 'http://localhost:3014'
    @reload_configuration()
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
    catch error
      @monitoring_lookups = {}
      @jmx_lookups = {}
      logger.error "Error reading configuration file: #{error}"

  ###
  Filter out a single agent by name.
  @param {String} agent The name of the agent to filter
  @return {Object} The matched up agent info
  ###
  agent_info: (agent) =>
    (@agents.filter (agent) -> agent.id == agent).pop()

  ###
  The list of client id's.
  @return {Array} The list of client id's
  ###
  client_list: =>
    @agents.map (agent) -> agent.id

  ###
  The list of http monitorable clients.
  @return {Array} The list of http monitorable client id's
  ###
  http_clients: =>
    @agents
    .filter((agent) ->
      agent.type != null and @http_clients[agent.formal_type] == 'http'
    ).map (agent) -> agent.id

  ###
  The list of jmx supported clients.
  @return {Array} The list of jmx monitorable client id's
  ###
  jmx_clients: =>
    @agents
    .filter((agent) =>
      agent.type != null and not (
        @jmx_lookups[agent.formal_type] == null or
        @jmx_lookups[agent.formal_type] == undefined)
    ).map (agent) -> agent.id

  ###
  Updates the current jolosrv client list with the existing agents.
  ###
  register_jolosrv_services: =>
    request.get "#{@j_url}/clients", json: true,
    timeout: 5000, (error, response, body) =>
      if error then logger.error error
      else
        clients_to_add = _.difference(@jmx_clients(), body.clients)
        clients_to_delete = _.difference(body.clients, @jmx_clients())

        if clients_to_add.length > 0
          async.each clients_to_add, add_jolokia_client, (error) ->
            logger.error error
        if clients_to_delete.length > 0
          async.each clients_to_delete, delete_jolokia_client, (error) ->
            logger.error error

  ###
  Deletes a client from jolokia.
  @param {String} client The name of the client to delete
  @param {Function} fn The callback function
  ###
  delete_jolokia_client: (client, fn) =>
    console.log "deleting client: #{client}"
    request.del "#{@j_url}/clients/#{client}", json: true,
    timeout: 2000, (error, response, body) =>
      return fn(error, body)

  ###
  Adds a client into jolokia.
  @param {String} client The name of the client to add
  @param {Function} fn The callback function
  ###
  add_jolokia_client: (client, fn) =>
    console.log "adding client: #{client}"
    agent = @agent_info(client)
    if agent == undefined
      return fn(true, "Agent `#{client}` could not be found")

    template = @jmx_lookups[agent.formal_type]
    if template == undefined or template == null
      return fn(true, "Unmonitorable agent `#{agent.formal_type}`")

    request.post "#{@j_url}/clients/#{client}", json: true,
    body:
      name: client
      url: "http://#{agent.url}/jolokia/"
      template: @jmx_lookups[agent.formal_type]
    , timeout: 2000, (error, response, body) =>
      return fn(error, body)

module.exports = GalaxyInfo
