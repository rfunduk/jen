var _ = require( 'underscore' );

exports.gist = function( meta ) {
  return function( filename ) {
    return "<script src='https://gist.github.com/" + (meta.gist||'0') + ".js?file=" + filename + "'></script>";
  }
};
exports.link_to = function( meta ) {
  return function( permalink, custom_title ) {
    if( custom_title ) {
      title = custom_title;
    }
    else {
      post = _.detect( meta.posts, function(p) {
        return p.permalink == permalink;
      } );
      if( post ) {
        title = post.title;
      }
      else {
        title = "MISSING POST";
      }
    }
    return "<a href='/" + permalink + "'>" + title + "</a>";
  };
};
