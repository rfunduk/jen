jade = require 'jade'
cp = require 'child_process'
fs = require 'fs'
_ = require 'underscore'
ejs = require 'ejs'
async = require 'async'
path = require 'path'
less = require 'less'
moment = require( 'moment' )
mkdir_p = require( 'mkdir_p' ).mkdir_p
coffeescript = require 'coffee-script'

Watcher = require './watcher'
Logger = require './logger'

Builder = exports

CWD = process.cwd()

jade.filters.plain = ( b, c ) ->
  return b.toString()

globalInfo = {}

Builder.reset = () ->
  globalInfo.PAGE_INFO = {}
  globalInfo.POST_INFO = {}

sortedPosts = () ->
  _(globalInfo.POST_INFO).chain()
    .values()
    .sortBy( (v) -> return v.timestamp.getTime() )
    .reverse()
    .value()

Builder.addInfo = ( path, kind, info ) ->
  globalInfo["#{kind.toUpperCase()}_INFO"][path] = info
Builder.getInfo = ( path, kind ) ->
  globalInfo["#{kind.toUpperCase()}_INFO"][path]

Config = null
Builder.config = ( config ) ->
  Config = config
  Logger.config Config

renderers = {}
innerContent = ( meta ) ->
  type = meta.extension
  switch type
    when 'md'
      meta.preprocessed = ejs.render( meta.src, locals: meta )
      renderers[type] ?= require( 'node-markdown' ).Markdown
      return renderers[type]( meta.preprocessed )
    when 'jade'
      renderers[type] ?= jade
      return renderers[type].compile( meta.src )(meta)
    when 'ejs'
      return ejs.render( meta.src, locals: meta )

Builder.render = ( path, kind, pathOverride=null ) ->
  meta = _.clone(Builder.getInfo( path, kind ))#_.clone( globalInfo["#{kind.toUpperCase()}_INFO"][path] )
  dir = "#{CWD}/build/#{meta.permalink}"
  mkdir_p dir, 0777, ( err ) ->
    if err
      Logger.error "Error in mkdir_p - #{dir} - #{err}"
      return
    Logger.debug "Processing #{meta.permalink}"
    meta.posts = sortedPosts()
    meta.pages = _.values(globalInfo.PAGE_INFO)
    meta.config = Config
    meta._ = _
    meta.h = _.reduce(
      _.keys( Config.helpers||{} ),
      (
        (uh, key) ->
          uh[key] = _.bind( Config.helpers[key], meta )
          return uh
      ),
      {
        moment: moment
        innerContent: innerContent
      }
    )

    try
      meta.content = innerContent( meta )
    catch e
      Logger.error "Could not process file: #{meta.permalink} - #{e}, #{e.stack}"
      return

    writeFile = ( dest, html ) ->
      fs.writeFile dest, html.toString(), ( err ) ->
        Logger.error "Error writing final render #{err}" if err
        Logger.debug "Wrote #{dest}"

    dest = pathOverride || "#{meta.permalink}/index.html"
    dest = "#{CWD}/build/#{dest}"

    if meta.layout == false
      writeFile( dest, meta.content )
    else
      fs.readFile "#{CWD}/_inc/#{meta.layout||'layout'}.jade", ( err, layout ) ->
        Logger.error( meta.permalink, err, err.stack ) if err
        tmpl = jade.compile layout.toString()
        html = tmpl( meta, (err) -> Logger.error("OMG#{err}") if err )
        writeFile( dest, html )

contentList = ( filenames ) ->
  _.reject( filenames || [], ( f ) -> f[0] == '.' || f[0] == '_' )

# find all pages
Builder.buildSite = () ->
  findFunctions =
    posts: ( cb ) ->
      fs.readdir "#{CWD}/_posts", ( err, listings ) ->
        # error is ok, no posts.
        cb( null, listings || [] )
    pages: ( cb ) ->
      paths = []
      processor = ( listing, done ) ->
        if listing == null
          done()
          return
        fs.stat "#{CWD}/_pages/#{listing}", ( err, stat ) ->
          if err
            Logger.error( "Could not stat file #{listing}" )
            done()
          else if stat.isFile()
            paths.push listing
            done()
          else
            fs.readdir "#{CWD}/_pages/#{listing}", ( err2, sublistings ) ->
              sublistings.forEach ( sublisting ) ->
                q.push( "#{listing}/#{sublisting}" )
              done()

      q = async.queue processor, 1

      fs.readdir "#{CWD}/_pages", ( err, listings ) ->
        # again, error is ok
        (listings || []).forEach ( listing ) -> q.push( listing )

      q.push( null ) # kick off queue, even if there are no posts
      q.drain = () -> cb( null, paths );

  async.parallel findFunctions, ( err, all ) ->
    pages = contentList( all.pages )
    posts = contentList( all.posts )
    f = ( kind ) ->
      return ( thing ) ->
        meta = Builder.getInfo( thing, kind )
        if Config.DEV || Config.drafts || !meta.draft
          if meta.permalink == Config.index || meta.index
            Logger.debug "  index: #{meta.permalink}"
            Builder.render( meta.thing, kind, 'index.html' )
          Logger.debug( "  #{kind}: #{meta.permalink}" )
          Builder.render meta.thing, kind
        else
          Logger.debug( "  skipped: #{thing}" )
    process = ( kind ) ->
      return ( thing ) ->
        return ( cb ) ->
          fs.readFile "#{CWD}/_#{kind}s/#{thing}", ( err, src ) ->
            Logger.error "Error reading source of #{thing} - #{err}" if err
            src = src.toString().split('---\n')
            meta = eval coffeescript.compile( src[0], { bare: true } )
            meta.scripts ?= []
            meta.styles ?= []
            meta.src = src.splice(1).join('---\n')

            pathParts = thing.split('.')
            meta.extension = pathParts.pop()
            pathParts = pathParts.pop().split('/')

            meta.filename = pathParts.pop()
            meta.path = pathParts.join('/')
            meta.path += '/' if meta.path
            meta.permalink = "#{meta.path}#{meta.filename}"

            meta.thing = "#{meta.permalink}.#{meta.extension}"

            if kind == 'post'
              dateFields = _.map(meta.date.split('.').reverse(), (f) -> parseInt(f, 10))
              meta.timestamp = new Date( dateFields[0], dateFields[1] - 1, dateFields[2] )

            meta.kind = kind

            # get any old info
            oldInfo = Builder.getInfo( meta.thing, kind )

            # port over info we populated on first run through
            meta.index = oldInfo.index if oldInfo

            # insert new info
            Builder.addInfo( meta.thing, kind, meta )
            cb() if cb

    pageProcess = process( 'page' )
    postProcess = process( 'post' )

    async.parallel(
      _.flatten( [
        _.map( pages, pageProcess ),
        _.map( posts, postProcess )
      ] ),
      ( err ) ->
        if not Config.index?
          # determine newest/index post
          newestThing = _.reject( sortedPosts(), (p) -> p.draft )[0].thing
          newestMeta = Builder.getInfo( newestThing, 'post' )
          newestMeta.index = true
          Builder.addInfo( newestThing, 'post', newestMeta )
          Logger.debug "  index: #{newestMeta.permalink}"
        pages.forEach f('page')
        posts.forEach f('post')
    )

    if Config.DEV
      pages.forEach ( thing ) ->
        Logger.debug "Watching #{thing}"
        Watcher.onChange "_pages/#{thing}", () ->
          pageProcess( thing )( () -> f('page')( thing ) )
      posts.forEach ( thing ) ->
        Logger.debug "Watching #{thing}"
        Watcher.onChange "_posts/#{thing}", () ->
          postProcess( thing )( () -> f('post')( thing ) )


Builder.compileStyles = () ->
  parser = new(less.Parser)(
    paths: [ process.cwd() + '/_styles' ]
  )
  f = ( style ) ->
    fs.readFile "_styles/#{style}", ( err, css ) ->
      return if err
      fs.mkdir "build/css", 0777, ( err ) ->
        done = ( err, src ) ->
          if err
            Logger.error "Could not process style: #{style}, #{JSON.stringify(err,undefined,2)}"
            return
          #log.info "SRC: #{src.toString()}"
          fs.writeFile "build/css/#{style.replace(/less$/, 'css')}", src.toString(), ( err ) ->
            Logger.error "Error in style done callback #{err}" if err
            Logger.debug "  style: #{style}"

        if style.match /less$/
          parser.parse( css.toString(), ( err, src ) ->
            if err
              done( err, src )
              return
            try
              result = src.toCSS( compress: true )
              done( null, result )
            catch err2
              done( err2, src )
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
              Logger.error "Error in script done callback #{err}" if err
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
        Logger.error "Error in static copy #{err}" if err
        if !Config.DEV
          src = "_static/#{static}"
          dest = "build/#{static}"
          cp.exec "cp -R #{src} #{dest}", ( err ) ->
            Logger.error "    Could not write build/#{static} during generation." if err
            Logger.error arguments if err
            Logger.error err if err
        else
          fs.symlink "../_static/#{static}", "build/#{static}", ( err ) ->
            Logger.error "Error symlinking statics #{err}" if err
