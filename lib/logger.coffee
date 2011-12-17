require 'colors'

fmt = ( kind, rest... ) ->
  colors =
    DEBUG: 'grey'
    INFO: 'blue'
    ERROR: 'red'
    WARN: 'yellow'
  kind = kind.toUpperCase()
  name = kind[colors[kind]].toString()
  padding = (' ' for i in new Array(5 - kind.length)).join('')
  "[" + name + padding + "] "

handleLogArgs = ( args ) -> args

exports._fmt = fmt
exports.debug = () -> console.log( fmt( 'debug' ), handleLogArgs(arguments)... ) if Config.DEBUG
exports.info = () -> console.log( fmt( 'info' ), handleLogArgs(arguments)... )
exports.error = () -> console.log( fmt( 'error' ), handleLogArgs(arguments)... )
exports.warn = () -> console.log( fmt( 'warn' ), handleLogArgs(arguments)... )
