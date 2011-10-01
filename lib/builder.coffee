jade = require 'jade'
cp = require 'child_process'
fs = require 'fs'
_ = require 'underscore'
ejs = require 'ejs'
async = require 'async'
path = require 'path'
less = require 'less'
md = require( 'node-markdown' ).Markdown
strftime = require( 'strftime' ).strftime
coffeescript = require 'coffee-script'

Watcher = require './watcher'
Logger = require './logger'

Builder = exports

CWD = process.cwd()

jade.filters.plain = ( b, c ) ->
  return b.toString()

try
  fs.statSync( "#{CWD}/custom.js" )
  custom = require "#{CWD}/custom"
  Logger.info "PLUGINS: #{_.keys(custom).join(',')}"
catch e
  Logger.info "PLUGINS: None"
  custom = {}

global =
  PAGE_INFO: {}
  POST_INFO: {}

sortedPosts = () ->
  _(global.POST_INFO).chain()
    .values()
    .sortBy( (v) -> return v.timestamp.getTime() )
    .reject( (v) -> return !Config.DEV && v.draft )
    .reverse()
    .value()

Builder.addInfo = ( path, kind, info ) ->
  global["#{kind.toUpperCase()}_INFO"][path] = info
Builder.getInfo = ( path, kind ) ->
  global["#{kind.toUpperCase()}_INFO"][path]

Config = null
Builder.config = ( config ) ->
  Config = config
  Logger.config Config

Builder.render = ( path, kind, pathOverride=null ) ->
  permalink = path.split('.')[0]
  fs.mkdir "#{CWD}/build/#{permalink}", 0777, ( err ) ->
    meta = _.clone( global["#{kind.toUpperCase()}_INFO"][path] )

    meta.kind = kind
    meta.posts = sortedPosts()
    meta.pages = _.values(global.PAGE_INFO)
    meta.config = Config
    meta._ = _
    meta.h = _.reduce(
      _.keys( custom ),
      (
        (uh, key) ->
          uh[key] = custom[key](meta)
          return uh
      ),
      { strftime: strftime }
    )

    meta.processed = ejs.render meta.src, locals: meta
    meta.content = md( meta.processed )

    fs.readFile "#{CWD}/_inc/layout.jade", ( err, layout ) ->
      tmpl = jade.compile layout.toString(), meta
      html = tmpl meta
      Logger.error( permalink, err, err.stack ) if err
      dest = pathOverride || "#{permalink}/index.html"
      fs.writeFile "#{CWD}/build/#{dest}", html.toString(), ( err ) ->
        Logger.error err if err


contentList = ( filenames ) ->
  _.reject( filenames || [], ( f ) -> f[0] == '.' || f[0] == '_' )

# find all pages
Builder.buildSite = () ->
  findFunctions =
    pages: ( cb ) -> fs.readdir "#{CWD}/_pages", cb
    posts: ( cb ) -> fs.readdir "#{CWD}/_posts", cb
  async.parallel findFunctions, ( err, all ) ->
    pages = contentList( all.pages )
    posts = contentList( all.posts )
    f = ( kind ) ->
      return ( thing ) ->
        meta = Builder.getInfo( thing, kind )
        if Config.DEV || !meta.draft
          if meta.permalink == Config.index
            Logger.debug "  index: #{meta.permalink}"
            Builder.render( thing, kind, 'index.html' )
          Builder.render thing, kind
          Logger.debug( "  #{kind}: #{meta.permalink}" )
        else
          Logger.debug( "  skipped: #{thing}" )
    process = ( kind ) ->
      return ( thing ) ->
        return ( cb ) ->
          fs.readFile "#{CWD}/_#{kind}s/#{thing}", ( err, src ) ->
            Logger.error err if err
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
            path.exists "#{CWD}/_static/img/#{meta.permalink}/thumb.png", ( yepnope ) ->
              meta.hasThumb = yepnope
              Builder.addInfo( thing, kind, meta )
              cb() if cb

    pageProcess = process( 'page' )
    postProcess = process( 'post' )

    async.parallel(
      _.flatten( [
        _.map( pages, pageProcess ),
        _.map( posts, postProcess )
      ] ),
      ( err ) ->
        pages.forEach f('page')
        posts.forEach f('post')
        if !Config.index
          # determine newest post
          newest = sortedPosts()[0]
          # and make it the index
          Logger.debug "  index: #{newest.permalink}"
          Builder.render newest.filename, 'post', 'index.html'
    )

    if Config.DEV
      Logger.info "DEV :: Watching for changes..."
      pages.forEach ( thing ) ->
        Watcher.onChange "_pages/#{thing}", () ->
          pageProcess( thing )( () -> f('page')( thing ) )
      posts.forEach ( thing ) ->
        Watcher.onChange "_posts/#{thing}", () ->
          postProcess( thing )( () -> f('post')( thing ) )


Builder.compileStyles = () ->
  parser = new(less.Parser)(
    paths: [ process.cwd() + '/_styles' ]
  )
  f = ( style ) ->
    fs.readFile "_styles/#{style}", ( err, css ) ->
      fs.mkdir "build/css", 0777, ( err ) ->
        done = ( err, src ) ->
          if err
            Logger.error "Could not process style: #{style}, #{err}"
            return
          #log.info "SRC: #{src.toString()}"
          fs.writeFile "build/css/#{style.replace(/less$/, 'css')}", src.toString(), ( err ) ->
            Logger.error err if err
            Logger.debug "  style: #{style}"

        if style.match /less$/
          parser.parse( css.toString(), ( err, src ) ->
            if err
              Logger.error "Could not process style: #{style}, #{err}"
              return
            done( null, src.toCSS( compress: true ) )
          )
        else
          done( null, css+"" )
  fs.readdir "_styles", ( err, styles ) ->
    buildAll = () -> contentList(styles).forEach f
    buildAll()
    styles.forEach ( style ) ->
      Watcher.onChange "_styles/#{style}", buildAll

Builder.compileScripts = () ->
  fs.readdir "_scripts", ( err, scripts ) ->
    contentList(scripts).forEach ( script ) ->
      f = () ->
        fs.readFile "_scripts/#{script}", ( err, coffee ) ->
          fs.mkdir "build/js", 0777, ( err ) ->
            src = if script.match( /coffee$/ ) then coffeescript.compile( coffee+"" ) else (coffee+"")
            fs.writeFile "build/js/#{script.replace(/coffee$/, 'js')}", src.toString(), ( err ) ->
              Logger.error err if err
              Logger.debug "  script: #{script}"
      f()
      Watcher.onChange "_scripts/#{script}", f

Builder.copyStatics = () ->
  # force delete anything that exists in data/static
  # and then based on env:
  #   development: symlink anything in data/static to build
  #   production:  fs copy anything in data/static to build
  fs.readdir "_static", ( err, statics ) ->
    contentList(statics).forEach ( static ) ->
      cp.exec "rm -rf build/#{static}", ( err ) ->
        Logger.error err if err
        if !Config.DEV
          src = "_static/#{static}"
          dest = "build/#{static}"
          cp.exec "cp -R #{src} #{dest}", ( err ) ->
            Logger.error "    Could not write build/#{static} during generation." if err
            Logger.error arguments if err
            Logger.error err if err
        else
          fs.symlink "../_static/#{static}", "build/#{static}", ( err ) ->
            Logger.error err if err
