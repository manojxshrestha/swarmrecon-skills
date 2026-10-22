---
name: Content Discovery
description: Recon-only discovery of unlinked paths, backups, VCS metadata, API docs, admin/debug endpoints, and framework routes. Use after crawling when the generic wordlist needs domain-specific and framework-specific paths.
---

# Content discovery

## Unique attack surface

Content discovery finds what the site does not link:

- forgotten admin, debug, metrics, health, and staging paths;
- backups and editor-generated files;
- source-control metadata (`.git`, `.svn`, `.hg`, `.bzr`, CVS);
- framework build artifacts and data routes;
- API documentation and schemas;
- configuration, logs, dumps, and exports;
- old file extensions and case variants;
- paths derived from the target's own domain and crawl corpus.

The unique risk is **a file or route that bypasses the intended navigation and
authorization**. The goal is inventory; do not brute-force credentials, exploit
uploads, or evade WAFs.

## Signals worth chasing

- Status/length/word differences from the baseline.
- `200` with a directory listing, source map, config, or backup content type.
- `301`/`302` to a login or admin path.
- `401`/`403` on an otherwise hidden path (still interesting).
- `500` with a stack trace or framework error.
- `.git/HEAD`, `.git/config`, `.svn/entries`, `.hg/requires`.
- `openapi.json`, `swagger.json`, `/v3/api-docs`, `swagger-resources`.
- `actuator`, `actuator/env`, `server-status`, `metrics`, `health`, `readyz`.
- `_next/data/<buildId>/`, `_next/image?url=`, `_ipx/`, `_gatsby/file`.
- `wp-json`, `wp-admin`, `xmlrpc.php`, `laravel`, `__debug`.
- Backup suffixes: `.bak`, `.old`, `.orig`, `.save`, `.swp`, `~`, `.zip`,
  `.tar`, `.tar.gz`, `.sql`, `.json`, `.1`, `.copy`.
- The same base name with different extensions or trailing slash.

## Safe collection

### 1. Generate a domain-derived wordlist

Use the target's own vocabulary, not only a generic list:

- apex labels and subdomain labels;
- product, environment, region, and team names;
- paths observed in crawl, archives, sitemaps, and JS;
- framework routes from `framework-routes`;
- backup permutations of observed file names;
- API/docs/debug paths.

Keep the existing `wordlists/high-value-paths.txt` as a baseline. A generated
list supplements it; it does not replace it.

### 2. Run a bounded discovery pass

Step 11 remains manual. Use `dir-bruteforce.sh` or a reviewed ffuf command:

```bash
ffuf -w generated-paths.txt:FUZZ \
  -u https://app.example.com/FUZZ \
  -mc 200,204,301,302,307,401,403,405,500 \
  -ac -rate 5 -t 20 -of json -o discovery.json
```

Keep a per-host budget, a baseline response, and a stop condition. Do not run
unbounded recursion.

### 3. Framework-specific routes

- Next.js: `_next/data/<buildId>/...`, `_next/image?url=...`, RSC headers,
  `__nextjs_original-stack-frame`, build manifests.
- Gatsby: `_gatsby/file`, page-data JSON.
- Nuxt: `_ipx/`, `__NUXT__`.
- SvelteKit/Astro/Remix: route manifests and data endpoints.
- WordPress: `wp-json/`, `wp-login.php`, `xmlrpc.php`.
- Spring: `actuator`, `actuator/env`, `actuator/heapdump` (detect only).
- ASP.NET: `trace.axd`, `elmah.axd`, `bin/`, `App_Data/`, `web.config`.
- Laravel: `.env`, `storage/logs/laravel.log`, `telescope`.

### 4. VCS and source exposure

Check only a small set of metadata paths:

```text
/.git/HEAD
/.git/config
/.svn/entries
/.hg/requires
/.bzr/branch/branch.conf
/CVS/Root
```

If a repository is exposed, record the evidence and stop. Do not dump it.

### 5. Backup permutations

For each observed file name, try a small suffix set:

```text
name
name.bak
name.old
name.orig
name.save
name.swp
name~
name.zip
name.tar.gz
name.sql
name.json
name.1
name.copy
```

Do not generate every combination of every extension. Keep the list bounded
and evidence-driven.

## Merge into swarmrecon

- Hits → `directories/<host>/` reports and `00-assets/urls.tsv`.
- New hosts → ledger and Step 14.
- VCS/config hits → `20-source-vcs/`.
- API docs → `17-js-api-cloud/`.
- Framework routes → `01-wappalyzer/framework-routes.tsv`.
- Manual queue with status, size, content type, and baseline diff.

## Stop lines

- Step 11 stays manual; do not auto-run it from the pipeline.
- No unbounded recursion or unlimited request budgets.
- No WAF evasion or rate-limit bypass.
- No destructive methods (PUT/POST/DELETE/PATCH).
- No credential brute force.
- No dumping an exposed repository or database.
- No out-of-scope hosts.

## Manual follow-up

- Is the path intentionally public?
- Does it expose source, config, data, or an admin function?
- Is the response a soft 404 or a WAF block page?
- Does the framework route require a build ID or auth?
- Is a backup current or stale?
- Is a VCS metadata path enough to reconstruct source, or only a fingerprint?

## Source notes

- Fuzzuli for domain-derived wordlists.
- Assetnote static-site-generator research for framework routes.
- ASP.NET source disclosure and VCS exposure research.
- Existing `dir-bruteforce.sh` reports and false-positive controls.
- Web Hacking Techniques Index records 12, 13, 25, 37.
