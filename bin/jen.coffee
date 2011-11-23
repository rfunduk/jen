#!/usr/bin/env coffee

require.paths.unshift __dirname + '/../node_modules'
require.paths.unshift __dirname + '/../lib'

coffeescript = require 'coffee-script'

fs = require 'fs'
express = require 'express'
_ = require 'underscore'
cp = require 'child_process'

argv = require('optimist').argv

if argv.seed
  SEED = true
else if argv.deploy
  DEPLOY = true
else if argv.build
  BUILD = true
else
  DEV = true

Logger = require 'logger'

if SEED
  wrench = require 'wrench'

  source = __dirname + '/../skeleton'
  dest = process.cwd() + '/' + argv.seed

  wrench.copyDirSyncRecursive( source, dest )

  Logger.info "SEEDED -> #{dest}"
  process.exit(0)

Config = require 'config'

Watcher = require 'watcher'
Builder = require 'builder'

if DEV
  Config.DEV = DEV
  Config.DEBUG = argv.debug

Builder.config Config
Logger.config Config

go = () ->
  rebuild = () ->
    Builder.reset()
    Builder.buildSite()
    Builder.compileStyles()
    Builder.compileScripts()
    Builder.copyStatics()

  # watch top level and re-do the whole site if they change
  fs.readdir process.cwd(), ( err, items ) ->
    items.forEach ( item ) ->
      return unless item.match( /^_/ )
      Watcher.onChange item, rebuild

  Watcher.onChange 'config', () -> Config._reload(); rebuild()
  Watcher.onChange '_inc/layout.jade', () -> rebuild()

  rebuild()

if Config.DEV
  go()

  app = express.createServer(
    express.logger( format: Logger._fmt( 'info' ) + " :method :url :status" ),
    ( req, res, next ) ->
      fs.stat "build/#{req.url}", ( err, stat ) ->
        if err || stat.isDirectory()
          req.url += '/'
        next()
    express.static('build')
  )

  app.listen Config.PORT

  Logger.info "DEV :: Server listening on :#{Config.PORT}"
else
  if BUILD
    Logger.info "BUILD"
    cp.exec "rm -rf build", () ->
      fs.mkdir "build", 0777, () ->
        go()
  if DEPLOY
    Logger.info "  DEPLOYING (w/ #{Config.deploy})"
    cp.exec Config.deploy, ( err ) ->
      Logger.error "  WTF? #{err}" if err
      Logger.info "  DONE" unless err


