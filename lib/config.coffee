fs = require 'fs'
_ = require 'underscore'

config = {}

mixins =
  _reload: () =>
    newConfig = JSON.parse( fs.readFileSync( process.cwd() + '/config.json' ) )
    _.extend( exports, config, newConfig, mixins )

mixins._reload()
