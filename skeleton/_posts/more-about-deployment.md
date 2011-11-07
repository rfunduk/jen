{
  "title": "More About Deployment",
  "description": "A post in which I explain: 'what is up with deployment?'",
  "date": "1.10.2011"
}
---
`config.json` includes a key: `deploy`. If you define it you
can have jen deploy for you easily.

You might put something in there like:

    rsync -r build/ sandwiches.com:/var/www/something/

Or maybe:

    s3cmd --config=etc/s3cfg --no-progress -r put build/ s3://blog.sandwiches.com

Simple.
