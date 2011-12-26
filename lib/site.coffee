fs = require 'fs'
_ = require 'underscore'
async = require 'async'

Watcher = require './watcher'
Finder = require './finder'
Server = require './server'

class Site
  constructor: ( @root=process.cwd() ) ->
    @config = Config
    @info = _.inject( Site.KINDS, (( h, k ) -> h[k] = {}; h ), {} )
    Logger.debug "SITE #{@}"
  determineIndex: () ->
    if @config.index?
      if (item = @info.pages[@config.index])?
        item.index = true
        Logger.debug "As index: #{item.kind}/#{item.permalink}"
    else
      # determine newest/index post
      newestThing = _.reject( @posts(), (p) -> p.draft )[0]
      newestThing.index = true
      Logger.debug "As index: #{newestThing.kind}/#{newestThing.permalink}"
  populateInfo: ( kind, items ) ->
    items.forEach ( item ) =>
      if !item.draft || @config.drafts
        @info[kind][item.permalink] = item
      else
        Logger.debug "Skipping #{item.kind}/#{item.permalink}"
  renderAll: ( kind, cb ) ->
    renderTasks = []
    for permalink, item of @info[kind]
      renderTasks.push( { item: item, fn: ( item ) -> ( cb ) -> item.render( cb ) } )

    renderFuncs = _.map( renderTasks, ( task ) -> task.fn(task.item) )
    async.parallel( renderFuncs, cb )
  watchContent: () ->
    again = @watchContent
    Site.KINDS.forEach ( kind ) =>
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
    cb ?= ( err ) -> Logger.error( "Could not reload content! #{err}" ) if err
    new Finder @, kind, ( err, items ) =>
      @populateInfo( kind, items )
      cb( err )
  processStyles: ( cb ) ->
    new Finder @, 'styles', ( err, styles ) =>
      @populateInfo( 'styles', styles )
      @renderAll( 'styles', cb )

  compileScripts: ( cb ) ->
    new Finder @, 'scripts', ( err, scripts ) =>
      @populateInfo( 'scripts', scripts )
      @renderAll( 'scripts', cb )
  copyStatics: ( cb ) ->
    new Finder @, 'statics', ( err, statics ) =>
      @populateInfo( 'statics', statics )
      @renderAll( 'statics', cb )
  posts: () ->
    _(@info.posts).chain()
      .values()
      .sortBy( (v) -> return v.timestamp )
      .reverse()
      .value()
  pages: () ->
    _(@info.pages).values()
  build: ( cb ) ->
    cb ?= ( err ) ->
      if err
        Logger.error "Site build failed! #{e}"
        return
      else
        Logger.info "Build complete."
    s = @
    async.parallel(
      [
        ( cb ) ->
          s.processContent 'posts', ( err ) ->
            cb( err, 'posts' )
        ( cb ) ->
          s.processContent 'pages', ( err ) ->
            cb( err, 'pages' )
        ( cb ) ->
          s.processStyles ( err ) ->
            cb( err, 'styles' )
        ( cb ) ->
          s.compileScripts ( err ) ->
            cb( err, 'scripts' )
        ( cb ) ->
          s.copyStatics ( err ) ->
            cb( err, 'statics' )
      ],
      ( err, loaded ) ->
        s.determineIndex()
        async.parallel(
          [
            ( cb ) -> s.renderAll( 'posts', cb )
            ( cb ) -> s.renderAll( 'pages', cb )
          ],
          cb
        )
    )
  developmentMode: () ->
    @build ( err ) =>
      site = @
      if err
        Logger.error err
        return
      else
        Logger.info "Initial build complete!"
        @watchContent()
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
        Watcher.onChange '_inc/layout.jade', () ->
          site.build()

Site.KINDS = [ 'pages', 'posts', 'styles', 'scripts', 'statics' ]

module.exports = Site
