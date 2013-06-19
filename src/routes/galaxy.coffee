os = require 'os'
hostname = os.hostname().split('.').shift()

clear = (req, res, next) ->
  res.app.locals.gi.clear()
  res.json 200, { message: "OK" }

showall = (req, res, next) ->
  res.json 200,
  agents: res.app.locals.gi.agents

show = (req, res, next) ->
  res.json 200,
  agents: res.app.locals.gi.agent_info("#{hostname}-s#{req.params.slot}")

status = (req, res, next) ->
  res.json 200, { message: req.params.slot }

update = (req, res, next) ->
  res.json 200, { message: "update" }

module.exports =
  clear: clear
  showall: showall
  show: show
  status: status
  update: update
