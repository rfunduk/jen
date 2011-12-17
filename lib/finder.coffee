cp = require 'child_process'
fs = require 'fs'
_ = require 'underscore'
_.str = require 'underscore.string'
async = require 'async'

CONTENT_TYPES = require './content'

class Finder
  constructor: ( @site, kind, cb ) ->
    site = @site
    kind = _.str.rtrim( kind, 's' )
    klass = _.str.capitalize(kind)
    @["_get#{klass}Paths"] ( err, filenames ) ->
      # filter the paths to exclude . and special files, etc
      filtered = _.reject( filenames || [], ( f ) -> f[0] == '.' || f[0] == '_' )
      # generate Content instances for each path
      contentGenerator = ( path, done ) ->
        content = new CONTENT_TYPES[klass]( site, path )
        content.process( done )
      async.map( filtered, contentGenerator, cb )
  _getStaticPaths: ( cb ) ->
    fs.readdir "#{@site.root}/_static", ( err, statics ) ->
      cb( err, statics || [] )
  _getStylePaths: ( cb ) ->
    fs.readdir "#{@site.root}/_styles", ( err, styles ) ->
      cb( err, styles || [] )
  _getScriptPaths: ( cb ) ->
    fs.readdir "_scripts", ( err, scripts ) ->
      cb( err, scripts || [] )
  _getPostPaths: ( cb ) ->
    fs.readdir "#{@site.root}/_posts", ( err, listings ) ->
      # error is ok, no posts.
      cb( null, listings || [] )
  _getPagePaths: ( cb ) ->
    site = @site
    paths = []
    processor = ( listing, done ) ->
      if listing == null
        done()
        return
      fs.stat "#{site.root}/_pages/#{listing}", ( err, stat ) ->
        if err
          Logger.error( "Could not stat file #{listing}" )
          done()
        else if stat.isFile()
          paths.push listing
          done()
        else
          fs.readdir "#{site.root}/_pages/#{listing}", ( err2, sublistings ) ->
            sublistings.forEach ( sublisting ) ->
              q.push( "#{listing}/#{sublisting}" )
            done()

    q = async.queue processor, 1

    fs.readdir "#{@site.root}/_pages", ( err, listings ) ->
      # again, error is ok
      (listings || []).forEach ( listing ) -> q.push( listing )

    q.push( null ) # kick off queue, even if there are no posts
    q.drain = () -> cb( null, paths );

module.exports = Finder
