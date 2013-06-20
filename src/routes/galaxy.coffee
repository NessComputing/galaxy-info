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

statusall = (req, res, next) ->
  res.json 200,
  status: res.app.locals.gi.status()

status = (req, res, next) ->
  res.app.locals.gi.status "#{hostname}-s#{req.params.slot}"
  , (err, status) =>
    res.json 200,
    status: status

update = (req, res, next) ->
  res.app.locals.gi.c
  res.json 200, { message: "update" }

module.exports =
  clear: clear
  showall: showall
  show: show
  statusall: statusall
  status: status
  update: update
