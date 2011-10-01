{
  "title": "More About Layout",
  "description": "A post in which I explain: 'what is up with layout?'",
  "date": "1.10.2011"
};
`_inc/layout.jade` defines the overall containing markup of
every generated page on the site.

Everything mentioned in the <%- h.link_to('intro', 'intro') %> is
available, but you don't use [ejs](https://github.com/visionmedia/ejs),
you use [jade](https://github.com/visionmedia/jade).

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

Look in `config.json` for the `styles` key. Notice it has 3 keys inside it.
`all`, `posts` and `pages`. You can see how those are used here since
`kind` is defined by the type of thing we're rendering. The last `styles || []`
is the optional array on posts/pages themselves.

Then we get into the body which is standard stuff.
