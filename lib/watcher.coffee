Content = require './content'

WATCH_OPTS =
  persistent: false
  interval: 1

fs = require 'fs'

watching = {}
exports.onChange = ( key, path, cb ) ->
  if typeof path is 'function'
    cb = path
    path = key
  unless watching[key]?
    Logger.debug "Watching #{key}..."
    watching[key] = true
    fs.watchFile path, WATCH_OPTS, ( newStat, oldStat ) ->
      cb() if oldStat.mtime < newStat.mtime
