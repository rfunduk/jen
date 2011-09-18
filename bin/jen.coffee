#!/usr/bin/env coffee

require.paths.unshift __dirname + '/../node_modules'
require.paths.unshift __dirname + '/../lib'

fs = require 'fs'
ejs = require 'ejs'
jade = require 'jade'
async = require 'async'
path = require 'path'
less = require 'less'
coffeescript = require 'coffee-script'
md = require( 'node-markdown' ).Markdown
strftime = require( 'strftime' ).strftime
express = require 'express'
_ = require( 'underscore' )._
cp = require 'child_process'
require 'colors'

cmd = process.argv.pop()

SEED = cmd == 'seed'
BUILD_ONLY = cmd == 'build' || cmd == 'deploy'
DEPLOY = cmd == 'deploy'

jade.filters.plain = ( b, c ) ->
  return b.toString()

# read config file
config = JSON.parse( fs.readFileSync( 'lib/config.json' ) )
config.DEV = !BUILD_ONLY

WATCH_OPTS =
  persistent: false
  interval: 1
  log: () -> #log.warn "WATCHFILE POLLING"
_fmt = ( kind, rest... ) ->
  colors =
    DEBUG: 'grey'
    INFO: 'blue'
    ERROR: 'red'
    WARN: 'yellow'
  kind = kind.toUpperCase()
  "[" + kind[colors[kind]].toString() + (' ' for i in new Array(5 - kind.length)).join('') + "] "
log =
  _handleLogArgs: ( args ) ->
    return args
  debug: () -> console.log( _fmt( 'debug' ), log._handleLogArgs(arguments)... )
  info: () -> console.log( _fmt( 'info' ), log._handleLogArgs(arguments)... )
  error: () -> console.log( _fmt( 'error' ), log._handleLogArgs(arguments)... )
  warn: () -> console.log( _fmt( 'warn' ), log._handleLogArgs(arguments)... )

log.info( "SITE: #{config.title}" )

try
  fs.statSync( "#{process.cwd()}/lib/custom.js" )
  custom = require "#{process.cwd()}/lib/custom"
  log.info "PLUGINS: #{_.keys(custom).join(',')}"
catch e
  log.info "PLUGINS: 'custom.js' not found."
  custom = {}

if SEED
  # just generate a new app
  skeleton =
    _scripts: false
    _static: false
    _styles: false
    _pages: false
    _posts: false
    _inc: false
    build: false
  _.keys( skeleton ).forEach ( dir ) ->
    fs.mkdir dir, 0777, ( err ) ->
      if err
        log.info "  SKIPPED #{dir}..."
      else
        log.info "  CREATED #{dir}..."
      skeleton[dir] = true
      if _.all( _.values( skeleton ), ( val ) -> val )
        log.info "  SEEDED!"
        process.exit(0)
else if DEPLOY
  #deploy_cmd = "rsync -e 'ssh -p #{config.remote.port}' -rv build/ #{config.remote.user}@#{config.remote.host}:#{config.remote.dir}"
  log.info "  DEPLOYING (w/ #{config.deploy})"
  cp.exec config.deploy, ( err ) ->
    log.error "  WTF? #{err}" if err
    log.info "  DONE" unless err
    process.exit(0)
else
  global =
    POST_INFO: {}
    PAGE_INFO: {}
  watching = {}

  sortedPosts = () ->
    _(global.POST_INFO).chain()
      .values()
      .sortBy( (v) -> return v.timestamp.getTime() )
      .reject( (v) -> return !config.DEV && v.draft )
      .reverse()
      .value()

  render = ( path, kind, pathOverride=null ) ->
    permalink = path.split('.')[0]
    fs.mkdir "build/#{permalink}", 0777, ( err ) ->
      meta = _.clone( global["#{kind.toUpperCase()}_INFO"][path] )

      meta.kind = kind
      meta.posts = sortedPosts()
      meta.pages = _.values(global.PAGE_INFO)
      meta.config = config
      meta._ = _
      meta.strftime = strftime

      meta.processed = ejs.render meta.src,
        locals:
          meta: meta
          posts: meta.posts
          pages: meta.pages
          _: _
          kind: kind
          permalink: meta.permalink
          config: config
          h: _.reduce(
            _.keys( custom.helpers ),
            (
              (uh, key) ->
                uh[key] = custom.helpers[key](meta)
                return uh
            ),
            {}
          ) if custom.helpers

      meta.content = md( meta.processed )

      fs.readFile "_inc/layout.jade", ( err, layout ) ->
        tmpl = jade.compile layout.toString(), meta
        html = tmpl meta
        log.error( permalink, err, err.stack ) if err
        dest = pathOverride || "#{permalink}/index.html"
        fs.writeFile "build/#{dest}", html.toString(), ( err ) ->
          log.error err if err
          log.debug( "    #{kind}: #{dest}" )

  # find all pages
  buildSite = () ->
    fs.readdir '_pages', ( err, pages ) ->
      log.info "  FOUND #{pages.length} PAGES"
      fs.readdir '_posts', ( err, posts ) ->
        log.info "  FOUND #{posts.length} POSTS"
        f = ( kind ) ->
          return ( thing ) ->
            meta = global["#{kind.toUpperCase()}_INFO"][thing]
            if config.DEV || !meta.draft
              r = () ->
                render thing, kind
                if meta.permalink == config.index
                  log.debug "    index: #{meta.permalink}"
                  render( thing, kind, 'index.html' )
              r()
              if !watching.hasOwnProperty thing
                watching[thing] = true
                fs.watchFile "_#{kind}s/#{thing}", WATCH_OPTS, ( n, o ) ->
                  WATCH_OPTS.log()
                  if o.mtime < n.mtime
                    process( kind, r )( thing )
            else
              log.warn( "  skipped: #{thing}" )
        process = ( kind, cb ) ->
          return ( thing ) ->
            fs.readFile "_#{kind}s/#{thing}", ( err, src ) ->
              log.error err if err
              src = src.toString().split(';\n')
              meta = JSON.parse src[0]
              meta.scripts = [] unless meta.scripts
              meta.styles = [] unless meta.styles
              meta.src = src.splice(1).join(';')
              meta.permalink = thing.split('.')[0]
              meta.filename = thing

              if kind == 'post'
                dateFields = _.map(meta.date.split('.').reverse(), (f) -> parseInt(f, 10))
                meta.timestamp = new Date( dateFields[0], dateFields[1] - 1, dateFields[2] )

              meta.kind = kind
              global["#{kind.toUpperCase()}_INFO"][thing] = meta
              path.exists "_static/img/#{meta.permalink}/thumb.png", ( yepnope ) ->
                meta.hasThumb = yepnope
                cb()

        todo =
          page: pages.length
          post: posts.length
        done = ( kind ) ->
          return () ->
            todo[kind]--
            if _.all( todo, ( val ) -> val == 0 )
              if !config.index
                # determine newest post
                newest = sortedPosts()[0]
                # and make it the index
                log.debug "    index: #{newest.permalink}"
                render newest.filename, 'post', 'index.html'
              pages.forEach f('page')
              posts.forEach f('post')

        pages.forEach process('page', done('page'))
        posts.forEach process('post', done('post'))

  compileStyles = () ->
    fs.readdir "_styles", ( err, styles ) ->
      styles.forEach ( style ) ->
        f = () ->
          fs.readFile "_styles/#{style}", ( err, css ) ->
            fs.mkdir "build/css", 0777, ( err ) ->
              done = ( err, src ) ->
                #log.info "SRC: #{src.toString()}"
                fs.writeFile "build/css/#{style.replace(/less$/, 'css')}", src.toString(), ( err ) ->
                  log.error err if err
                  log.debug "    style: #{style}"

              if style.match /less$/
                less.render( css+"", done )
              else
                done( null, css+"" )

        f()
        fs.watchFile "_styles/#{style}", WATCH_OPTS, ( n, o ) ->
          WATCH_OPTS.log()
          f() if o.mtime < n.mtime

  compileScripts = () ->
    fs.readdir "_scripts", ( err, scripts ) ->
      scripts.forEach ( script ) ->
        f = () ->
          fs.readFile "_scripts/#{script}", ( err, coffee ) ->
            fs.mkdir "build/js", 0777, ( err ) ->
              src = if script.match( /coffee$/ ) then coffeescript.compile( coffee+"" ) else (coffee+"")
              fs.writeFile "build/js/#{script.replace(/coffee$/, 'js')}", src.toString(), ( err ) ->
                log.error err if err
                log.debug "    script: #{script}"
        f()
        fs.watchFile "_scripts/#{script}", WATCH_OPTS, ( n, o ) ->
          WATCH_OPTS.log()
          f() if o.mtime < n.mtime

  go = () ->
    log.info "  BUILDING PAGES"
    buildSite()
    log.info "  BUILDING STYLESHEETS"
    compileStyles()
    log.info "  BUILDING SCRIPTS"
    compileScripts()

    # watch inc files and re-do the whole site if they change
    fs.readdir "_inc", ( err, incs ) ->
      incs.forEach ( inc ) ->
        fs.watchFile "_inc/#{inc}", WATCH_OPTS, ( n, o ) ->
          WATCH_OPTS.log()
          buildSite() if o.mtime < n.mtime

    # watch config file and re-do whole site if it changes
    fs.watchFile "config.json", WATCH_OPTS, ( n, o ) ->
      WATCH_OPTS.log()
      buildSite() if o.mtime < n.mtime

    log.info "  COPYING STATICS"
    # force delete anything that exists in data/static
    # and then based on env:
    #   development: symlink anything in data/static to build
    #   production:  fs copy anything in data/static to build
    fs.readdir "_static", ( err, statics ) ->
      statics.forEach ( static ) ->
        cp.exec "rm -rf build/#{static}", ( err ) ->
          log.error err if err
          if !config.DEV
            src = "_static/#{static}"
            dest = "build/#{static}"
            cp.exec "cp -R #{src} #{dest}", ( err ) ->
              log.error "    Could not write build/#{static} during generation." if err
              log.error arguments if err
              log.error err if err
          else
            fs.symlink "../_static/#{static}", "build/#{static}", ( err ) ->
              log.error err if err

  if config.DEV
    go()

    log.info "  STARTING DEVELOPMENT SERVER"
    app = express.createServer(
      express.logger( format: _fmt( 'info' ) + " :method :url :status" ),
      ( req, res, next ) ->
        if fs.statSync( "build/#{req.url}" ).isDirectory()
          req.url += '/'
        next()
      express.static('build')
    )

    app.listen config.PORT

    log.info "  LISTENING on #{config.PORT}"
  else
    log.info "  BUILD ONLY"
    cp.exec "rm -rf build", () ->
      fs.mkdir "build", 0777, () ->
        go()
