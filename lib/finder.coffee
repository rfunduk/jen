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
    @_getNestedPaths klass, ( err, filenames ) ->
      if err
        Logger.error( "Could not find #{klass}s!" )
        return

      # filter the paths to exclude . and special files, etc
      filtered = _.reject( filenames || [], ( f ) -> f[0] == '.' || f[0] == '_' )

      # generate Content instances for each path
      contentGenerator = ( path, done ) ->
        content = new CONTENT_TYPES[klass]( site, path )
        content.process( done )

      async.mapSeries( filtered, contentGenerator, cb )
  _getNestedPaths: ( kind, cb ) ->
    rootPath = "#{@site.root}/_#{kind.toLowerCase()}s"
    rootPathRemover = new RegExp( "^#{rootPath}/" )

    walk = ( dir, done ) ->
      results = []
      fs.readdir dir, ( err, list ) ->
        return done( err ) if err

        pending = list.length
        return done( null, results ) unless pending > 0

        list.forEach ( file ) ->
          fullpath = "#{dir}/#{file}"
          fs.stat fullpath, ( err, stat ) ->
            if stat && stat.isDirectory()
              walk fullpath, ( err, res ) ->
                results = results.concat(res)
                pending--
                done( null, results ) unless pending > 0
            else
              rpath = fullpath.replace( rootPathRemover, '' )
              results.push rpath
              pending--
              done( null, results ) unless pending > 0

    walk rootPath, cb

module.exports = Finder
