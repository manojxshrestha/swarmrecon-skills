---
name: Framework Routes
description: Recon-only mapping of framework-specific routes and build artifacts for Next.js, React, Gatsby, Nuxt, SvelteKit, Astro, Remix, Angular, Vue, WordPress, Laravel, Spring, and ASP.NET. Use when technology detection shows a framework and the generic wordlist is missing its routes.
---

# Framework routes

## Unique attack surface

Frameworks expose routes and build artifacts that are not in generic
wordlists:

- Next.js `_next/data/<buildId>/...`, image optimizer, RSC headers, middleware,
  build manifests;
- React source maps, chunk names, component data flow;
- Gatsby `_gatsby/file`, page-data JSON, build manifests;
- Nuxt `_ipx/`, `__NUXT__`, server routes;
- SvelteKit/Astro/Remix data endpoints and route manifests;
- Angular/Vue build chunks and environment config;
- WordPress REST (`wp-json`), XML-RPC, plugin/theme assets;
- Laravel debug pages, logs, Telescope;
- Spring Boot Actuator;
- ASP.NET trace/ELMAH/config paths.

The unique risk is **a framework-generated route or artifact that bypasses the
intended navigation** (data route, image proxy, middleware, debug endpoint).
Detection is read-only; no framework exploit modules.

## Signals worth chasing

- `X-Powered-By`, `Server`, cookies, and HTML meta generator.
- `_next/static/`, `_next/data/`, `__NEXT_DATA__`, `build-manifest.json`.
- `_gatsby/`, `page-data.json`, `app-data.json`.
- `_ipx/`, `__NUXT__`, `_nuxt/`.
- `__sveltekit`, `__data.json`, `_app/`.
- `astro-island`, `_astro/`.
- `__remixContext`, `_root.data`.
- `wp-json`, `wp-content/`, `wp-includes/`.
- `laravel`, `telescope`, `storage/logs/`.
- `actuator`, `actuator/env`, `actuator/health`.
- `trace.axd`, `elmah.axd`, `__browserLink`.

## Safe collection

### 1. Fingerprint

```bash
httpx -l https-subs.txt -tech-detect -title -status-code -web-server \
  -no-color -o tech.txt
```

Use `01-wappalyzer` output and response headers. Record versions only; do not
run version-specific exploits.

### 2. Next.js

- Extract build ID from `__NEXT_DATA__`, `_next/static/<buildId>/`, or
  `build-manifest.json`.
- Enumerate `_next/data/<buildId>/<route>.json` only for routes already
  observed or clearly linked.
- Inspect `_next/image?url=...` and `_next/static/` for source maps.
- Record RSC headers (`RSC`, `Next-Router-State-Tree`) if present.
- Do not attempt middleware bypass or cache poisoning.

### 3. Gatsby / Nuxt / SvelteKit / Astro / Remix

- Fetch build/page-data manifests.
- Record route names and data endpoints.
- Inspect `_gatsby/file`, `_ipx/`, `__data.json`, `_root.data` only for
  in-scope paths.
- Do not send state-changing requests.

### 4. Angular / Vue / React

- Extract chunk names and source maps.
- Look for environment config (`environment.ts`, `runtime-config.js`).
- Use the JS/source-map skill for endpoint and secret extraction.
- Do not execute bundles.

### 5. WordPress

- `wp-json/` for route inventory.
- `wp-login.php`, `xmlrpc.php` for surface presence.
- Plugin/theme versions from readme/assets.
- Do not attempt credential attacks or plugin exploits.

### 6. Laravel / Spring / ASP.NET

- Laravel: debug pages, `storage/logs/laravel.log`, Telescope.
- Spring: `actuator`, `actuator/health`, `actuator/env` (detect only; do not
  dump secrets).
- ASP.NET: `trace.axd`, `elmah.axd`, `web.config`, `bin/`, `App_Data/`.

## Merge into swarmrecon

```text
01-wappalyzer/framework-routes.tsv
framework  version_hint  route  source  status  notes
```

Feed routes into:

- `14-high-value/dynamic-paths.txt`;
- `17-js-api-cloud/endpoints.tsv`;
- `20-source-vcs/exposure.tsv` for config/debug paths.

## Stop lines

- No framework exploit modules, deserialization payloads, or middleware bypass.
- No cache poisoning or request smuggling.
- No credential attacks against admin panels.
- No dumping actuator/env/logs beyond a short evidence excerpt.
- No execution of downloaded bundles.
- No unbounded route enumeration.

## Manual follow-up

- Is the build ID/data route intentionally public?
- Does the image optimizer fetch arbitrary URLs?
- Are source maps public in production?
- Are debug/actuator endpoints exposed?
- Is the framework version end-of-life?
- Does the route expose data that the UI does not?

## Source notes

- Assetnote, *Exploiting Static Site Generators: When Static Is Not Actually
  Static*.
- *Next.js and the corrupt middleware: the authorizing artifact*.
- React2Shell (fingerprint only).
- ReactAppScan / TranSPArent for component/data-flow surface.
- Web Hacking Techniques Index records 13, 35, 39, 41, 42.
