fs = require 'fs'
path = require 'path'

routes = {}
fs.readdirSync(__dirname)
.map (file) ->
  file.replace /.js$/, ""
.filter (file) ->
  file != "index"
.map (route) ->
  routes[route] = require "./#{route}"

module.exports = routes
