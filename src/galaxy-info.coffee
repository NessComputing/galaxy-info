{exec} = require 'child_process'
os = require 'os'
fs = require 'fs'

config = require 'nconf'
logger = require './logger'
request = require 'request'
_ = require 'lodash'
async = require 'async'

###
The Galaxy Info cache.
###
class GalaxyInfo
  constructor: ->
    @agents = []
    @health = {}

    @configuration = {}
    @http_lookups = {}
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
        setTimeout () =>
          @update_galaxyinfo()
        , 100
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
          @register_http_services()
        catch error
          logger.warn "Unable to parse galaxy show-json output: #{error}"

  ###
  Clears the slot info and reloads config.
  ###
  clear: =>
    clearInterval(@update_timer)
    @update_timer = null
    @agents = []
    @health = {}
    @reload_configuration()
    @initialize_updater()

  ###
  Reads the galaxy-info configuration file and sets up svc mappings.
  ###
  reload_configuration: =>
    try
      @configuration = JSON.parse(
        fs.readFileSync(config.get('config')).toString())
      @http_lookups = @configuration.services
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
    @agents.filter (a) -> a.id == agent

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
    .filter((agent) =>
      agent.type != null and @http_lookups[agent.formal_type] == 'http'
    ).map (agent) -> agent.id

  ###
  Registes
  ###
  register_http_services: =>
    clients_to_add = _.difference(@http_clients(), Object.keys(@health))
    clients_to_delete = _.difference(Object.keys(@health), @http_clients())
    delete @health[d] for d in clients_to_delete
    @health[d] = 'unknown' for d in clients_to_add

  ###
  Returns the selfcheck status for a given agent.
  @param {String} agent The name of the agent to retrieve status for
  @param {Function} fn The callback function
  ###
  status: (agent=null, fn) =>
    # if agent == null
    #   async.map Object.keys(@agents), @single_status, fn
    # else
    @single_status(agent, fn)

  ###
  Returns a selfcheck status for a single agent.
  ###
  single_status: (agent, fn) =>
    ainfo = @agent_info(agent).shift() || {}
    astate = ainfo.status
    hstate = @health[agent]?.status
    hmessage = @health[agent]?.message
    type = if ainfo.type then ainfo.type else ainfo.id

    if astate == "stopped"
      return fn(null,
        state: "ERROR"
        message: "#{type} is stopped")

    if astate == "running"
      if hstate == "OK" or hstate == undefined or hstate == null
        message = hmessage || "is OK"
        return fn(null,
          state: if hstate then hstate.toUpperCase() else "OK"
          message: "#{type} #{message}")
      else
        message = hmessage || "is throwing #{hstate.toUpperCase()}'s"
        return fn(null,
          state: if hstate then hstate.toUpperCase() else "ERROR"
          message: "#{type} #{message}")
    else
      message = hmessage || "is OK"
      return fn(null,
        state: if hstate then hstate.toUpperCase() else "OK"
        message: "#{type} #{message}")

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
          async.each clients_to_add, @add_jolokia_client, (error) ->
            logger.error error
        if clients_to_delete.length > 0
          async.each clients_to_delete, @delete_jolokia_client, (error) ->
            logger.error error

  ###
  Deletes a client from jolokia.
  @param {String} client The name of the client to delete
  @param {Function} fn The callback function
  ###
  delete_jolokia_client: (client, fn) =>
    request.del "#{@j_url}/clients/#{client}", json: true,
    timeout: 2000, (error, response, body) =>
      return fn(error, body)

  ###
  Adds a client into jolokia.
  @param {String} client The name of the client to add
  @param {Function} fn The callback function
  ###
  add_jolokia_client: (client, fn) =>
    agent = @agent_info(client).shift()
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
