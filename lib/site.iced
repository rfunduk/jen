fs = require 'fs'
_ = require 'underscore'
async = require 'async'
mkdir_p = require( './mkdir_p' ).mkdir_p

Watcher = require './watcher'
Finder = require './finder'
Server = require './server'

class Site
  constructor: ( @root=process.cwd() ) ->
    @config = Config
    @cleanInfo = _.inject( Site.KINDS, (( h, k ) -> h[k] = {}; h ), {} )
    @reset()
  determineIndex: () ->
    if @config.index?
      if (item = @info.pages[@config.index])?
        item.isIndex = true
        Logger.debug "As index: #{item.kind}/#{item.permalink}"
    else
      # determine newest/index post
      newestThing = _.reject( @posts(), (p) -> p.draft )[0]
      newestThing.isIndex = true
      Logger.debug "As index: #{newestThing.kind}/#{newestThing.permalink}"
  populateInfo: ( kind, items ) ->
    items.forEach ( item ) =>
      if !item.draft || @config.drafts
        @info[kind][item.permalink] = item
      else
        Logger.debug "Skipping #{item.kind}/#{item.permalink}"
  renderAll: ( kind, cb ) ->
    async.map(
      _.values(@info[kind])
      ( item, callback ) -> item.render( callback )
      cb
    )
  renderLayout: ( layout, obj, cb ) ->
    @info['layouts'][layout].render( obj, cb )
  reset: ( cb ) ->
    mkdir_p( "#{@root}/build", 0o0777, cb ? (()->) )
    @info = _.clone( @cleanInfo )
  watchContent: ( kind ) ->
    again = @watchContent
    for permalink, item of @info[kind]
      toWatch = "_#{item.kind}s/#{item.srcPath}"
      Watcher.onChange toWatch, "#{@root}/#{toWatch}", (( itemToProcess ) ->
        () ->
          itemToProcess.process ( err, processed ) ->
            if err
              Logger.error "Could not re-process watched #{itemToProcess.kind}, #{err}"
              return

            itemToProcess.render ( err ) =>
              if err
                Logger.error "Clould not re-render watched #{itemToProcess.kind}, #{err}"
                return
      )(item)
  processContent: ( kind, cb ) ->
    new Finder @, kind, ( err, items ) =>
      @populateInfo( kind, items )
      cb()

  posts: () ->
    _(@info.posts).chain()
      .values()
      .sortBy( (v) -> return v.timestamp )
      .reverse()
      .value()
  pages: () ->
    _(@info.pages).values()
  layouts: () ->
    _(@info.layouts).values()
  build: ( done ) ->
    s = @
    done ?= ( err ) ->
      if err
        Logger.error "Site build failed! #{e}"
        return
      else
        Logger.info "Build complete."
    @reset ->
      Logger.info "Processing content..."
      for kind, i in Site.KINDS
        await s.processContent( kind, defer e )

      s.determineIndex()

      Logger.info "Rendering content..."
      for kind, i in _.reject( Site.KINDS, (k) -> k == 'layouts' )
        await s.renderAll( kind, defer e )

      done()
  developmentMode: () ->
    @build ( err ) =>
      site = @
      if err
        Logger.error err
        return
      else
        Logger.info "Initial build complete."

        # watch and reprocess everything except layouts
        Site.KINDS.forEach ( kind ) =>
          return if kind == 'layouts' # watched below, rebuilds whole site
          return if kind == 'statics' # not necessary to watch, symlinked
          @watchContent( kind )

        # watch layouts for change and rebuild whole site
        for permalink, item of @info.layouts
          toWatch = "_layouts/#{item.srcPath}"
          Watcher.onChange toWatch, "#{@root}/#{toWatch}",  () -> site.build()

        # watch for new files in top level ^_.* directories
        # and re-do the whole site if they change
        fs.readdir @root, ( err, items ) ->
          items.forEach ( item ) ->
            return unless item.match( /^_/ )
            Watcher.onChange item, () ->
              site.build( () ->
                site.watchContent()
              )

        # watch config file
        Watcher.onChange 'config.coffee', () ->
          site.config._reload()
          site.build()

Site.KINDS = [ 'layouts', 'pages', 'posts', 'styles', 'scripts', 'statics' ]

module.exports = Site
