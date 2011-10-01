WATCH_OPTS =
  persistent: false
  interval: 1

fs = require 'fs'

watching = {}
exports.onChange = ( file, cb ) ->
  unless watching.hasOwnProperty file
    watching[file] = true
    fs.watchFile file, WATCH_OPTS, ( newStat, oldStat ) ->
      cb() if oldStat.mtime < newStat.mtime
