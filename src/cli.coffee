optimist = require 'optimist'
logger = require './logger'
config = require 'nconf'
require('pkginfo')(module, 'name', 'version')

###
The command line interface class.
###
class CLI
  constructor: () ->
    @argv = optimist
      .usage("Usage: " + exports.name)

      # monitoring configuration
      .alias('c', 'config')
      .describe('c', 'The monitoring configuration file to use')
      .default('c', "/etc/galaxy-info.json")

      # logging
      .alias('l', 'loglevel')
      .describe('l', 'Set the log level (debug, info, warn, error, fatal)')
      .default('l', 'warn')

      # port
      .alias('p', 'port')
      .describe('p', 'Run the api server on the given port')
      .default('p', 3015)

      # help
      .alias('h', 'help')
      .describe('h', 'Shows this message')
      .default('h', false)

      # version
      .alias('v', 'version')
      .describe('v', 'Shows the current version')
      .default('v', false)

      # append the argv from the cli
      .argv

    @configure()

    if config.get('help').toString() is "true"
      optimist.showHelp()
      process.exit(0)

    if config.get('version').toString() is "true"
      console.log "#{exports.name}: #{exports.version}"
      process.exit(0)

  # Configures the nconf mapping where the priority matches the order
  configure: () =>
    @set_overrides()
    @set_argv()
    @set_env()
    @set_defaults()

  # Sets up forceful override values
  set_overrides: () =>
    config.overrides({
      })

  # Sets up the configuration for cli arguments
  set_argv: () =>
    config.add('optimist_args', {type: 'literal', store: @argv})

  # Sets up the environment configuration
  set_env: () =>
    config.env({
      whitelist: []
      })

  # Sets up the default configuration
  set_defaults: () =>
    config.defaults({
      })

module.exports = new CLI()
