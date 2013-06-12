require('pkginfo')(module, 'name', 'version')

# Returns the base name and version of the app.
version = (req, res, next) ->
  res.json 200, 
    name: exports.name,
    version: exports.version

module.exports = version
