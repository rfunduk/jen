PORT: 3000
index: "home"
title: "Jen - Static Site Generator"
root: "http://jen.ryanfunduk.com"
analytics_id: "UA-XXXXXXX-N"
deploy: "rsync -r build/ somehost.com:/var/www/something/"
helpers:
  url_for: ( permalink ) ->
    "/#{permalink}"
  link_to: ( permalink, custom_title ) ->
    return "<strike>MISSING</strike>" unless @_.detect( @_.flatten([@posts,@pages]), ( p ) -> p.permalink == permalink )
    "<a href='#{@h.url_for(permalink)}'>#{custom_title || @title}</a>"
