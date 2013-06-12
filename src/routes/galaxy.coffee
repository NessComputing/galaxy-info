clear = (req, res, next) ->
  res.app.locals.gi.clear()
  res.json 200, { message: "OK" }

showall = (req, res, next) ->
  res.json 200, { message: "showall" }

show = (req, res, next) ->
  res.json 200, { message: "show" }

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
