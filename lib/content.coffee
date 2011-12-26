coffee = require 'coffee-script'
cp = require 'child_process'
fs = require 'fs'
_ = require 'underscore'
moment = require 'moment'
less = require 'less'
jade = require 'jade'
ejs = require 'ejs'
mkdir_p = require( './mkdir_p' ).mkdir_p
coffeescript = require 'coffee-script'

jade.filters.plain = ( b, c ) ->
  return b.toString()

SRC_DELIM = '---\n'

renderers = {}
innerContent = ( meta ) ->
  type = meta.extension
  switch type
    when '.md'
      meta.preprocessed = ejs.render( meta.src, meta )
      renderers[type] ?= require( 'node-markdown' ).Markdown
      return renderers[type]( meta.preprocessed )
    when '.jade'
      renderers[type] ?= jade
      return renderers[type].compile( meta.src )(meta)
    when '.ejs'
      return ejs.render( meta.src, meta )

class GenericContent
  constructor: ( @site, @srcPath ) ->
    @kind = @constructor.name.toLowerCase()
  process: ( cb ) ->
    pathParts = @srcPath.split('.')
    if pathParts.length > 1
      @extension = ".#{pathParts.pop()}"
      pathParts = pathParts.join('.').split('/')
    else
      @extension = ""
      pathParts = @srcPath.split('/')

    @filename = pathParts.pop()
    @path = pathParts.join('/')
    @path += '/' if @path
    @permalink = "#{@path}#{@filename}"
    @fullPath = "#{@site.root}/_#{@kind}s/#{@srcPath}"

    @thing = "#{@permalink}#{@extension}"

    Logger.debug "Processing #{@kind}/#{@permalink}..."
    if cb then cb( null, @ ) else @

  render: ( cb ) ->
    Logger.debug "Rendering #{@kind}/#{@permalink}..."
    if cb then cb( null, @ ) else @

class PageOrPost extends GenericContent
  constructor: ( @site, @srcPath, @kind ) ->
    super( @site, @srcPath )
    @isIndex = false
    @draft = false
  process: ( cb ) ->
    super()
    fs.readFile @fullPath, ( err, src ) =>
      if err
        Logger.error "Error reading source of #{@kind}/#{@srcPath} - #{err}"
        cb( err, @ )
        return

      src = src.toString().split( SRC_DELIM )
      meta = eval coffee.compile( src[0], { bare: true } )

      for k, v of meta
        @[k] = v
      @scripts ?= []
      @styles ?= []
      @src = src.splice(1).join( SRC_DELIM )

      if @kind == 'post'
        @timestamp = moment( meta.date, @site.config.dateFormat || "DD.MM.YYYY" )

      cb( null, @ )
  render: ( cb ) ->
    super()
    dir = "#{@site.root}/build/#{@permalink}"
    mkdir_p dir, 0777, ( err ) =>
      if err
        Logger.error "Error in mkdir_p - #{dir} - #{err}"
        cb( err, null )
        return

      @posts = @site.posts()
      @pages = @site.pages()

      @config = @site.config
      @_ = _

      self = @
      @h = _.reduce(
        _.keys( Config.helpers||{} ),
        (
          (uh, key) ->
            uh[key] = _.bind( Config.helpers[key], self )
            return uh
        ),
        {
          _: _,
          moment: moment
          innerContent: innerContent
        }
      )

      try
        @content = innerContent( @ )
      catch e
        Logger.error "Could not process file: #{@permalink} - #{e}, #{e.stack}"
        return

      writeFile = ( dest, html, cb ) =>
        fs.writeFile dest, html.toString(), ( err ) =>
          Logger.error "Error writing final render #{err}" if err
          cb( err )

      dest = "#{@site.root}/build/#{@permalink}/index.html"

      if @layout == false
        writeFile( dest, @content, cb )
      else
        fs.readFile "#{@site.root}/_inc/#{@layout||'layout'}.jade", ( err, layoutSrc ) =>
          Logger.error( @permalink, err, err.stack ) if err
          tmpl = jade.compile layoutSrc.toString()
          html = tmpl( @, (err) -> Logger.error("OMG#{err}") if err )
          writeFile( dest, html, ( err ) =>
            if @isIndex
              writeFile( "#{@site.root}/build/index.html", html, (err) -> cb(err, true) )
            else
              cb( err, true )
          )

class Page extends PageOrPost
  constructor: ( @site, @srcPath ) ->
    super( @site, @srcPath, 'page' )
class Post extends PageOrPost
  constructor: ( @site, @srcPath ) ->
    super( @site, @srcPath, 'post' )


class Script extends GenericContent
  render: ( cb ) ->
    super()
    fs.readFile @fullPath, ( err, coffee ) =>
      fs.mkdir "#{@site.root}/build/js", 0777, ( err ) =>
        src = if @extension == '.coffee'
                coffeescript.compile( coffee+"" )
              else
                coffee+""
        fs.writeFile "#{@site.root}/build/js/#{@thing.replace(/coffee$/, 'js')}", src.toString(), ( err ) ->
          Logger.error "Error in script done callback #{err}" if err
          cb( null, true )

class Style extends GenericContent
  render: ( cb ) ->
    super()
    parser = new(less.Parser)(
      paths: [ "#{@site.root}/_styles" ]
    )
    fs.readFile @fullPath, ( err, css ) =>
      return cb( err ) if err
      fs.mkdir "#{@site.root}/build/css", 0777, () =>
        done = ( err, src ) =>
          if err
            Logger.error "Could not process style: #{@permalink}, #{JSON.stringify(err,undefined,2)}"
            cb( err )
            return
          fs.writeFile "#{@site.root}/build/css/#{@thing.replace(/less$/, 'css')}", src.toString(), ( err ) ->
            Logger.error "Error in style done callback #{err}" if err
            cb( null, true )

        if @extension == '.less'
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

class Static extends GenericContent
  render: ( cb ) ->
    # force delete anything that exists in data/static
    # and then based on env:
    #   development: symlink anything in data/static to build
    #   production:  fs copy anything in data/static to build
    super()
    cp.exec "rm -rf #{@site.root}/build/#{@thing}", ( err ) =>
      if err
        Logger.error "Error in static copy #{err}"
        cb( err )
        return

      src = "#{@site.root}/_static/#{@thing}"
      dest = "#{@site.root}/build/#{@thing}"

      if !@site.config.DEV
        cp.exec "cp -R #{src} #{dest}", ( err ) =>
          if err
            Logger.error "Could not write build/#{@thing} during generation. #{arguments}, #{err}"
            cb( err )
          else
            cb( null, true )

      else
        fs.symlink src, dest, ( err ) ->
          if err
            Logger.error "Error symlinking statics #{err}"
            cb( err )
          else
            cb( null, true )

module.exports =
  Page: Page
  Post: Post
  Script: Script
  Style: Style
  Static: Static
