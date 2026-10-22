---
name: JavaScript and Source Maps
description: Recon-only analysis of public JavaScript bundles and source maps for endpoints, parameters, frameworks, cloud configuration, and redacted secret candidates. Use after crawling, or whenever the site is a SPA or framework build.
---

# JavaScript and source maps

## Unique attack surface

Modern web clients ship the application's routing, API calls, feature flags,
and sometimes configuration to the browser. Source maps can reconstruct the
original source. The unique surface is **the client-side map of the backend**:

- API paths and HTTP methods that the UI calls;
- GraphQL operations and tRPC procedures;
- WebSocket/SSE endpoints;
- hidden/admin routes and feature flags;
- internal hostnames, staging URLs, and cloud project IDs;
- SDK configuration (Firebase, Supabase, Sentry, Algolia, Stripe publishable
  keys);
- source maps with original file paths, comments, and sometimes secrets;
- build IDs and manifests that unlock framework-specific routes.

The goal is static extraction and inventory. Do not execute untrusted bundles,
use credentials, or call mutations.

## Signals worth chasing

- `//# sourceMappingURL=...` or `/*# sourceMappingURL=... */`.
- `.map` files return `200` and contain `sourcesContent`.
- `__NEXT_DATA__`, `__NUXT__`, `__NEXT_BUILD_ID`, `build-manifest.json`,
  `asset-manifest.json`, `_next/static/`, `_next/data/`.
- `webpackChunk`, `__webpack_require__`, Vite `import.meta.env`, Rollup
  chunks.
- `firebaseConfig`, `supabaseUrl`, `supabaseKey`, `S3_BUCKET`,
  `cloudfront`, `googleapis`, `algolia`, `sentry`, `stripe`.
- `fetch(`, `axios`, `XMLHttpRequest`, `useQuery`, `createTRPCClient`,
  `graphql`, `wss://`, `socket.io`.
- Strings that look like `/api/v1/...`, `/graphql`, `/trpc/...`,
  `/rest/...`, `/internal/...`.
- Source paths containing `admin`, `internal`, `staging`, `dev`, `beta`,
  `debug`.

## Safe collection

### 1. Collect public JS

```bash
# From crawl URLs, keep JS
grep -Ei '\.(js|mjs|cjs)(\?|$)' merged-crawl.txt | sort -u > js/js-urls.txt

# Or use dedicated discovery tools if installed
subjs -i https-subs.txt -o js/subjs.txt
getJS --input https-subs.txt --output js/getjs.txt
```

Download with a browser-like UA, timeout, and a size cap. Keep the original URL
and response hash.

### 2. Find source maps

```bash
# For each JS file, extract sourceMappingURL and resolve relative to the JS URL
rg -o 'sourceMappingURL=[^[:space:]]+' js/files/ > js/sourcemap-refs.txt
```

Fetch `.map` files only from in-scope hosts. Validate that the map contains
`sourcesContent` or `sources`; do not follow a map URL to a third-party host
unless that host is in scope.

### 3. Reconstruct source

Use `sourcemapper` or a small parser to write reconstructed trees under
`js/sourcemaps/`. Keep a manifest mapping original path → map URL → JS URL.

Do not run `npm install`, build scripts, or any code from the reconstructed
tree.

### 4. Extract endpoints and parameters

Use `jsluice`, `LinkFinder`, or a reviewed regex pass:

```bash
jsluice urls js/files/ > js/urls.jsonl
jsluice secrets js/files/ > js/secrets.jsonl
```

Normalize into:

```text
url  method_hint  source_file  context  confidence
```

Look for path templates and object IDs. Feed them to `api-surface`.

### 5. Cloud and SDK configuration

Extract keys and endpoints without using them:

- Firebase: `apiKey`, `authDomain`, `projectId`, `storageBucket`,
  `messagingSenderId`, `appId`.
- Supabase: `supabaseUrl`, `supabaseKey` (anon).
- Sentry: DSN.
- Algolia: app ID, search-only key.
- Stripe: publishable key (`pk_...`; not a secret by itself).
- Google: `AIza...`.
- AWS: `AKIA...`, `ASIA...`, bucket names, region.
- Mapbox, Auth0, Okta, Cognito client IDs.

Record presence, location, and type. Mask the value.

### 6. Framework metadata

Extract:

- Next.js build ID and `_next/data` route pattern;
- RSC headers and `Next-Router-State-Tree`;
- middleware/build manifests;
- Gatsby `_gatsby/file` references;
- Nuxt `_ipx` references;
- Remix/SvelteKit/Astro route manifests;
- Webpack/Vite chunk names.

Feed to `framework-routes`.

## Merge into swarmrecon

```text
17-js-api-cloud/
├── js/
│   ├── js-urls.txt
│   ├── files/
│   ├── sourcemaps/
│   └── manifest.tsv
├── endpoints.tsv
├── params.tsv
├── cloud-config.tsv
├── secrets-redacted.tsv
└── js-report.md
```

Ledger types: `js`, `url`, `api`. Edges: `references`, `calls`,
`contains_secret`.

## Stop lines

- Do not execute downloaded JavaScript.
- Do not use, validate, or replay a discovered key/token.
- Do not call mutations or state-changing endpoints.
- Do not fetch source maps from third-party hosts outside scope.
- Do not reconstruct or publish proprietary source beyond what is necessary
  for the review.
- Do not store full secret values; mask and redact.

## Manual follow-up

- Which endpoints are only called by the client and never linked?
- Are feature flags exposing admin/beta routes?
- Does the source map reveal internal hostnames or staging environments?
- Are cloud keys present, and what is their intended scope?
- Are source maps intentionally public in production?
- Does the build ID unlock a data route that is not otherwise discoverable?

## Evidence format

```text
source_url  asset_url  method_hint  context  detector  confidence  redacted_value
```

Keep a hash of each downloaded file and the timestamp. Full secrets stay out of
reports.

## Source notes

- TranSPArent, ReactAppScan, EvoCrawl (client-side code/state surface).
- Assetnote static-site-generator research and Next.js middleware/React2Shell
  for framework routes and build artifacts.
- Truffle Security for public-secret exposure.
- Web Hacking Techniques Index records 14, 15, 35, 39, 41, and 42.
