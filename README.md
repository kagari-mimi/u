# karari-mimi/u

This repository contains a Ruby script and a GitHub Action
which will generate a RSS feed from MangaDex `/chapter` API endpoint.

You should be able to subscribe to the feed
by putting the URL below into your RSS reader of choice:

```
https://kagari-mimi.github.io/u
```

## FAQ

> How often does the feed refreshes?

The [cron job][cron] is set to run at every 5 minutes.
However, we're at GitHub's mercy on how often it will get run
as it seems like free projects do get throttle somewhat.

[cron]: https://github.com/kagari-mimi/u/blob/95fdc7e5d203e80cf6a506328f301e49a8423fe6/.github/workflows/build-atom-feed.yml#L8

> Why does the feed only contain a few items?

This is due to API limitation
as the [`/chapter` endpoint][endpoint] only returns a maximum of 100 chapters at a time.
It also doesn't support filtering by tag,
so the tag filtering is done locally
on the latest 300 chapters we receive from MangaDex.

[Latest Updates]: https://mangadex.org/titles/latest
[endpoint]: https://api.mangadex.org/docs/redoc.html#tag/Chapter/operation/get-chapter

> Why `/u/`?

Because Y/u/ri.

> Why does this feed uses the word "Girls' love" instead of "Yuri"?

I decided to use this term to match the [actual tag name][tag] on MangaDex.

[tag]: https://mangadex.org/tag/a3c67850-4684-404e-9b7f-c69850ee5da6/girls-love
