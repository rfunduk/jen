fs = require 'fs'
coffee = require 'coffee-script'
_ = require 'underscore'

config = {}

mixins =
  _reload: () =>
    configFile = "#{process.cwd()}/config"
    contents = fs.readFileSync( configFile ).toString()
    compiled = coffee.compile( contents, { bare: true } )
    newConfig = eval compiled
    if newConfig
      _.extend( exports, config, newConfig, mixins )
    else
      console.log "Could not parse config file #{configFile}"

mixins._reload()
