{
  "title": "Have you met Jen?",
  "description": "A page to show how jen works."
}
---
This is a skeleton app. You will find the overall
style and layout (including this text) in
`_inc/layout.jade`. Other places of
interest:


### `config.json`

Overall site configuration. Some of these keys
are required, but you can populate it with
whatever you need to render your views.

For example, the `PORT` key is used to run the
development server you are likely viewing right now.

But you'll notice that the `scripts`
key is simply used in the `head` of
`layout.jade` to write out script tags.
You could choose a different approach or strategy
if you wanted, like even just hard-coding the
script tags, thus making the key not required.


### `custom.js`

Since `config.json` is truly a JSON file,
it cannot include functions. So consider `custom.js`
to be the function part of your configuration. Specify
here any functions you want available to your pages/posts
and to the layout.

Included in this skeleton app are two examples. A helper
for outputting a [gist](https://gist.github.com),
and a helper for linking to another post by permalink.

Follow the same format and write whatever functions you
will need.


### `etc/`

Simply a place to put other stuff you may need.
Maybe you want to deploy this to a webserver which
requires a pem key? Or maybe you want to write a
script for some reason? `etc` is a
perfect place to put that stuff.


### `build/`

Where the built site, the result of the generation,
will be placed, served from in development mode
and eventually deployed from.


### `_styles/`

Put `.less` files in here, they will be processed,
and you can refer to their eventual `.css` name
in your config or in your views.

Eg. If you write a `mysite.less`, then you'll want to
refer to `/css/mysite.css` somewhere in your config/pages/posts.

Regular `.css` files in `_styles` are simply copied over.
So feel free to write plain CSS if you like.


### `_scripts/`

Basically as above but with `.less` replaced with `.coffee`
and `.css` and CSS replaced with `.js` and JavaScript :)


### `_posts/` and `_pages/`

Blog posts and pages! Either is optional. You can have no
pages or no posts (making what is not really a blog, of course).

The general idea is to put at the top of each one a
`JSON` block that describes it:

      {
        "title": "POST TITLE",
        "description": "POST DESCRIPTION",
        "date": "DD.MM.YYYY",
        "draft": true|false
      }
      ---

Wait! It's actually evaluated with [CoffeeScript](http://coffeescript.org/)!
That means you can be way sexier:

      title: "POST TITLE"
      description: "POST DESCRIPTION"
      date: "DD.MM.YYYY"
      draft: true|false
      ---

Posts don't require a date, and the `draft` field is optional
in both cases.

The following local variables are accessible inside the layout,
posts and pages:

- **`kind`**: the kind of document being rendered. For example
  this is a _<%- kind %>_.
- **`permalink`**: the url-friendly permalink name of the document.
  This is determined by the filename. This <%- kind %>s permalink
  is _<%- permalink %>_.
- **`timestamp`**: For posts. A JavaScript
  [`Date`](https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Date)
  corresponding to the `date` field of the post.
- **`scripts`** and **`styles`**: Arrays of JavaScript and CSS
  files to be included by this document only. This is assuming
  you keep the script/style related stuff intact in the skeleton's
  `_inc/layout.jade`. You could also make extensions or changes to
  this based on your needs.
- **`pages`** and **`posts`**: Arrays of all pages and all posts.
  For example, this site has <%- posts.length %> post(s) and
  <%- pages.length %> page(s). You might write some navigation of some
  kind, etc, using these.
- **`h`**: Helpers, [`moment`](http://momentjs.com/) is included for you,
  but the rest are all defined by you in `config` under the `helpers` key.
- **`config`**: The site's overall configuration, as seen and
  defined in `config`. Having this available means you can
  configure your app however makes sense to you. Want to show
  the 5 most recent posts on the bottom of every page on the site?
  You could hardcode the `5` but it would be better to add
  `"post_count": 5` to `config` and then use this value
  in the views. For example, the example configuration has a key:
  `custom_setting`, it's value is <%- config.custom_setting %>.
- **`_`**: [Underscore](http://documentcloud.github.com/underscore/),
  very handy for looping and finding things (relevant posts, maybe?).

