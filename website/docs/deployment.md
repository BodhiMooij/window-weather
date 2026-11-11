# Deployment

The download page is **https://windowweather.bodhimooij.com**.

bodhimooij.com already points at Vercel, and its DNS is served by Strato
(`shades02.rzone.de` / `docks20.rzone.de`). Publish this `website` directory as
its own Vercel project, with the root directory set to `website`. `vercel.json`
builds `dist` and serves that static output. In the Vercel project, add the
domain `windowweather.bodhimooij.com`. In Strato DNS, add a CNAME:

    windowweather.bodhimooij.com.  CNAME  cname.vercel-dns.com.

The free Mac download is a public GitHub release and does not need the payment
Worker. Paid checkout still goes through the Cloudflare Worker below, which
accepts only `https://windowweather.bodhimooij.com` as the checkout origin.

## Cloudflare Worker

The `snowy` Worker serves payment API routes with Cloudflare Static Assets. It
uses small SQLite Durable Objects for checkout idempotency, rate buckets and
webhook deduplication. Static files still bypass Worker execution. There is no
client analytics.

## Publish

Use Node.js 22 or later and an authorized Cloudflare account with access to the
active `aauburn.com` zone. The checked-in account ID is a public identifier,
not a credential.

```sh
cd website
npm ci
npx wrangler whoami
# Secrets must already exist: POLAR_ACCESS_TOKEN and POLAR_WEBHOOK_SECRET
npm test
npm run check
npm run deploy:dry-run
npm run deploy
```

Wrangler is pinned as a development dependency. The deploy command rebuilds
`dist` before upload. Authentication stays in Wrangler's local credential
store; never add tokens to this repository. For unattended deployments, use a
scoped account-owned API token in the CI secret store rather than committing
OAuth credentials.

`wrangler.jsonc` still owns the earlier `snowy.aauburn.com` Custom Domain.
Leave that route in place: `bodhimooij.com` is not in that Cloudflare account,
so a custom domain for `windowweather.bodhimooij.com` cannot be attached there. The
`workers.dev` and version preview URLs are disabled.
The earlier private Sites preview remains a separate publication.

## Delivery behavior

- Only `dist` is uploaded, excluding its private build marker.
- `_headers` supplies the CSP, content-type protection, referrer policy, and
  disabled camera/microphone/geolocation permissions.
- Missing assets return 404; there is no application-shell fallback.
- ETag/revalidation caching keeps unversioned JavaScript, CSS, and audio current
  after deploys. The `no-transform` directive prevents zone-level automatic Web
  Analytics script injection on this site, without changing other hostnames.
  The small MP3 is loaded only after a user interaction.
- The free DMG is a public GitHub release asset and needs no checkout or login.

After deployment, verify the main page, JavaScript, SVG favicon, audio MIME/range
responses, a missing-file 404, and the $0 download. No app launch or performance
benchmark is part of deployment verification.

References: [Static Assets](https://developers.cloudflare.com/workers/static-assets/),
[Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/),
[asset headers](https://developers.cloudflare.com/workers/static-assets/headers/),
[automatic analytics injection](https://developers.cloudflare.com/web-analytics/faq/).
