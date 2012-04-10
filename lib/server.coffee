express = require 'express'
fs = require 'fs'

class Server
  constructor: ( @site ) ->
    @app = express.createServer(
      Config.DEBUG && express.logger( format: Logger._fmt( 'info' ) + " :method :url :status" )
      ( req, res, next ) ->
        fs.stat "build/#{req.url}", ( err, stat ) ->
          if err || stat.isDirectory()
            req.url += '/'
          next()
      express.static("#{@site.root}/build")
    )
  start: () ->
    @app.listen Config.PORT
    Logger.info "DEV :: Server listening on :#{Config.PORT}"

module.exports = Server
