fs = require 'fs'
CSON = require 'cson'
_ = require 'underscore'

config = {}

mixins =
  _reload: () =>
    newConfig = CSON.parseFileSync "#{process.cwd()}/config"
    _.extend( exports, config, newConfig, mixins )

mixins._reload()
