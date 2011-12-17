PORT: 3000
index: "home"
title: "My Site"
root: "http://mysite.com"
analytics_id: "UA-XXXXXXX-N"
deploy: "rsync -r build/ somehost.com:/var/www/something/"
scripts:
  all: [ "skeleton.js" ]
  post: []
  page: []
styles:
  all: [ "skeleton.css" ]
  post: []
  page: []
custom_setting: 123
numbers: [ 1, 2, 3 ]
helpers:
  gist: ( filename ) ->
    "<script src='https://gist.github.com/#{@gist||'0'}.js?file=#{filename}'></script>"
  url_for: ( permalink ) ->
    "/#{permalink}"
  link_to: ( permalink, custom_title ) ->
    return "<strike>MISSING</strike>" unless @_.detect( @_.flatten([@posts,@pages]), ( p ) -> p.permalink == permalink )
    "<a href='#{@h.url_for(permalink)}'>#{custom_title || @title}</a>"
