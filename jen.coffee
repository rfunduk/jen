fs = require 'fs'
cp = require 'child_process'

argv = require('optimist').argv

global.Logger = require './lib/logger'

if argv.seed
  wrench = require 'wrench'

  source = __dirname + '/skeleton'
  dest = process.cwd() + '/' + argv.seed

  wrench.copyDirSyncRecursive( source, dest )

  Logger.info "SEEDED -> #{dest}"
  process.exit(0)

DEPLOY = argv.deploy
BUILD = argv.build
DEV = !DEPLOY && !BUILD

global.Config = require './lib/config'

Config.DEV = DEV
Config.drafts = DEV || argv.drafts
Config.DEBUG = argv.debug || false

Site = require './lib/site'
site = new Site

if Config.DEV
  site.developmentMode()

  Server = require('./lib/server')
  new Server( site ).start()
else
  deploy = () ->
    deployCmd = Config.deploy
    if typeof(deployCmd) == 'object'
      deployCmd = Config.deploy[argv.deploy]
      deployCmd = Config.deploy[Config.deploy.default] unless deployCmd
    Logger.info "DEPLOY :: #{deployCmd}"
    cp.exec deployCmd, ( err ) ->
      if err
        Logger.error "WTF? #{err}"
      else
        Logger.info "DEPLOY :: Complete"

  if BUILD
    Logger.info "BUILD :: Building site (./build)"
    cp.exec "rm -rf #{site.root}/build/*", () ->
      fs.mkdir "#{site.root}/build", 0777, () ->
        site.build ( err ) ->
          Logger.info "BUILD :: Complete"
          if err
            Logger.error "Error building site: #{err}"
            return
          deploy() if DEPLOY
  else
    deploy() if DEPLOY


