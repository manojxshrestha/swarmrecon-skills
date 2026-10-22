---
name: Archive and OSINT
description: Recon-only expansion from web archives, passive DNS, and public OSINT sources. Use when current crawl data is thin, or when forgotten hosts, parameters, and endpoints may still exist.
---

# Archive and OSINT

## Unique attack surface

Historical and third-party sources reveal what the current site does not:

- old URLs, parameters, and API paths;
- subdomains and staging hosts that no longer resolve;
- deprecated endpoints still deployed;
- historical DNS and certificate records;
- public documents, code, and issue trackers that mention internal names;
- URLScan/Common Crawl snapshots of pages that changed.

The unique risk is **stale evidence being mistaken for current truth**.
Archives are clues, not proof. The 2025 archive-integrity research shows that
archives can be incomplete or manipulated, so every hit needs provenance and
liveness verification.

## Signals worth chasing

- A URL/host appears in an archive but not in current DNS/HTTP.
- Old parameters or API versions that still respond.
- Historical DNS points at a different provider or origin.
- URLScan shows a page/response that the current site hides.
- Common Crawl has paths that `robots.txt` or the sitemap omitted.
- A public document/repo mentions an internal hostname or environment.
- The same host appears in multiple archives with different content.

## Safe collection

### 1. Wayback CDX

```bash
curl -sS --max-time 60 \
  'https://web.archive.org/cdx/search/cdx?url=example.com&matchType=domain&output=json&fl=timestamp,original,statuscode,mimetype&collapse=urlkey&limit=5000' \
  -o archive/wayback.json
```

Keep `timestamp`, `original`, `statuscode`, and `mimetype`. Normalize URLs and
dedupe.

### 2. Common Crawl

Use an index query or a client that records the collection/segment. Keep the
source collection and timestamp. Do not assume a Common Crawl URL is live.

### 3. URLScan

```bash
curl -sS --max-time 30 'https://urlscan.io/api/v1/search/?q=domain:example.com&size=100' \
  -o archive/urlscan.json
```

Review public scans for hostnames, paths, and technologies. Do not submit a
new scan of a third party without authorization.

### 4. Passive DNS / OSINT

When API keys are available and the engagement permits:

- VirusTotal, SecurityTrails, PassiveTotal, AlienVault OTX;
- certificate transparency (separate skill);
- public code and issue trackers;
- search engines with exact-host queries.

Record the source, query, and timestamp. Do not scrape at high volume.

### 5. Existing tools

```bash
gau --threads 5 --subs example.com > archive/gau.txt
waymore -i example.com -mode U -oU archive/waymore.txt
waybackurls example.com > archive/waybackurls.txt
uro < archive/all-urls.txt | sort -u > archive/normalized.txt
```

`gau`/`waymore` may already use multiple providers. Record which provider is
enabled; a count without provenance is not actionable.

### 6. Verify before promotion

For every candidate:

1. scope check;
2. DNS resolution;
3. HTTP GET/HEAD;
4. compare title/status/content type to the archive;
5. mark `historical` if it does not resolve.

Only live, in-scope URLs enter `https-subs.txt`; historical ones stay in
`archive/dead-hosts.tsv`.

## Merge into swarmrecon

```text
13-crawl/
├── archive-urls.tsv      # url, source, collection, timestamp, status
├── archive-hosts.txt     # hosts seen historically
├── dead-hosts.tsv        # historical only, not live
└── archive-summary.md
```

Ledger: `type=url`/`host`, `source=wayback|commoncrawl|urlscan|otx|vt|st|gau`.
Edges: `references`, `same_host`, `historical`.

## Stop lines

- Do not treat an archived URL as live without probing.
- Do not use archived credentials or tokens.
- Do not submit scans of third parties without authorization.
- Do not scrape at high volume or bypass API limits.
- Do not interact with archive-manipulation techniques.
- Do not promote out-of-scope historical hosts into active testing.

## Manual follow-up

- Does the historical host still resolve, and to what?
- Is the old endpoint still deployed but unlinked?
- Did the provider/origin change over time?
- Is the archive snapshot complete, or is content missing/manipulated?
- Are old parameters still accepted?
- Is the host owned by the target or by a third party?

## Source notes

- *The Power to Never Be Wrong: Evasions and Anachronistic Attacks Against Web
  Archives* (archive caveats).
- Web Hacking Techniques Index record 16.
- Existing Step 13 `waymore`/`gau` pipeline.
