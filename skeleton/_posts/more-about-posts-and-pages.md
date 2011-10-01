{
  "title": "More About Posts &amp; Pages",
  "description": "A post in which I explain: 'what is up with posts and pages?'",
  "date": "1.10.2011"
};
Pages and posts are practically the same. The key difference is
that pages are not dated.

Generally you'll want to skip some layout stuff for pages. Like
not writing out date strings next to titles, or not inserting
a disqus comment section, etc.

    - if( kind == 'post' ) {
      post specific stuff here,
      disqus? tweet button, etc.
    - }

You'll do this in `_inc/layout.jade` and thus your
actual source files for posts and pages aren't much different than
each other.

The other detail you need to write posts and pages is
how the variables and whatnot available are accessed.

Posts and pages are _pre_-processed with
[ejs](https://github.com/visionmedia/ejs).
Helpers that output HTML need to be written like so:

<pre><code>&lt;%- h.link_to( 'permalink' ) %&gt;</code></pre>

For logic you can just leave it bare, and for non-markup
or markup you want escaped you can use the <code>&lt;%=</code> form:

<pre><code>&lt;% [ 'img1', 'img2', 'img3' ].forEach( function(img) { %&gt;

  ![](/img/&lt;%= img %&gt;.png)
&lt;% } ) %&gt;</code></pre>

Which would render:

    <img src="/img/img1.png" />
    <img src="/img/img2.png" />
    <img src="/img/img3.png" />

This example is possibly not the best use of `ejs` :)
Probably the most common use will simply be for using helpers
you define in `custom.js`.
