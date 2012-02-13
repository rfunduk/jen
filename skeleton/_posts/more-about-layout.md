title: "More About Layout"
"description": "A post in which I explain: 'what is up with layout?'"
"date": "1.10.2011"
layout: "test"
---
`_layouts/default.jade` defines the overall containing markup of
every generated page on the site.

However, this peticular post is actually using a _different_ layout. It
is identical to `default.jade` but written in [`haml-coffee`](https://github.com/9elements/haml-coffee).
You can use any of the same engines as posts for layouts. Just give
the layout the appropriate extension and either name it `default` or specify
the name in the data at the top of your document (eg: `layout: "test"` in this post's source).

Everything mentioned in the <%- h.link_to('intro', 'intro') %> is
available in layouts.

In there, you'll see a pretty standard start to a site.

    !!! 5

    html
      head
        title= config.title + ' &raquo; ' + title
        meta( name='description', content=description )
        meta( charset='utf-8' )

        link( rel='canonical', href="#{config.root}/#{permalink}" )

So this will make an HTML5 page, the title will
be <span style='white-space: nowrap;'><code>SITE TITLE &raquo; CONTENT TITLE</code></span>.
Meta this, meta that, and the canonical url.

Then we get into some fancy stuff:

    styles = _.flatten( [
      config.styles.all,
      config.styles[kind],
      styles || []
    ] );

    ... etc

Look in `config.coffee` for the `styles` key. Notice it has 3 keys inside it.
`all`, `posts` and `pages`. You can see how those are used here since
`kind` is defined by the type of thing we're rendering. The last `styles || []`
is the optional array on posts/pages themselves.

This isn't something 'built-in' to jen, though. This is just an example
of what you could do, and it is pretty handy. Just keep in mind that you can
have just a single key of 'styles' and 'scripts' and not do any of that
flattening and stuff... Or maybe you just hardcode the names of your styles
and scripts... Whatever!

Then we get into the body which is standard stuff.
