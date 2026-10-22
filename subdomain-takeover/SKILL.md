---
name: Subdomain Takeover
description: Recon-only detection of dangling CNAMEs and unclaimed hosted-service names. Use when a hostname points at Heroku, GitHub Pages, S3, Netlify, Vercel, Shopify, or similar providers but no longer serves the expected app.
---

# Subdomain takeover

## Unique attack surface

A subdomain takeover exists when a DNS record still delegates a name to a
third-party service, but the service no longer has a tenant for that name. An
attacker who can create the missing tenant may inherit the name, its cookies,
its email, and its trust relationships.

The unique surface is **the gap between DNS and provider state**, not the web
root:

- dangling `CNAME` → provider returns a "not found / unclaimed" page;
- `CNAME` → `NXDOMAIN` at the tail;
- wildcard DNS that makes every random label look alive;
- a provider that accepts a new app/site/bucket with the same name;
- ownership verification that follows a CNAME and accepts a token found at the
  alias target (the ALIASLEAP class of flaw);
- a provider page that still serves a valid TLS certificate for the victim
  name, masking the takeover.

Detection is read-only. Claiming, registering, or creating the resource is out
of scope.

## Signals worth chasing

- `dig +short CNAME host` ends at a provider hostname, but the provider
  returns `404`, `No such app`, `There isn't a GitHub Pages site here`,
  `NoSuchBucket`, or a generic "site not found" page.
- The CNAME tail does not resolve (`NXDOMAIN`) while the victim name still
  resolves to the provider edge.
- The provider returns a different body for a random subdomain than for the
  victim subdomain.
- TLS certificate CN/SAN does not match the victim name, or the provider's
  default certificate is served.
- A wildcard `*.example.com` resolves for a random label; this is a DNS
  configuration finding, not automatically a takeover.
- The provider's verification instructions mention a CNAME or a token behind a
  CNAME.
- The record is old, the app is gone, but the CNAME was never removed.

## Safe collection

### 1. Expand CNAME chains

```bash
# One host at a time
dig +short CNAME app.example.com
dig +short A app.example.com
dig +short AAAA app.example.com

# Batch, with CNAME and response data
dnsx -cname -a -aaaa -resp -no-color -l hosts.txt -o dns-map.txt
```

Follow the chain to the final target. Record every hop; a provider can appear
in the middle even if the last hop is a CDN.

### 2. Fingerprint the provider response

Use GET/HEAD only:

```bash
curl -sS -L --max-time 15 -D headers.txt \
  -o body.html https://app.example.com/
```

Record:

- final URL and redirect chain;
- status code;
- title and a small body hash;
- `Server`, `Via`, `X-GitHub-Request-Id`, `X-Served-By`, `X-Cache`;
- known provider error text.

Do not download large bodies. A bounded first page is enough.

### 3. Provider fingerprint set

Start with a versioned YAML/JSON list. At minimum:

| Provider | CNAME / edge hints | Common unclaimed signal |
|---|---|---|
| Heroku | `herokuapp.com`, `herokudns.com` | `No such app` |
| GitHub Pages | `github.io`, `github.map.fastly.net` | `There isn't a GitHub Pages site here` |
| GitHub Actions Pages | `github.io` | Pages not deployed / 404 |
| Shopify | `myshopify.com` | `Sorry, this shop is currently unavailable` |
| Desk | `desk.com` | `This Desk is not active` |
| Squarespace | `squarespace.com` | `No site configured` |
| Fastly | `fastly.net` | `Fastly error: unknown domain` |
| Pantheon | `pantheonsite.io` | `The gods are wise` / 404 |
| Tumblr | `tumblr.com` | `There's nothing here` |
| WordPress.com | `wordpress.com` | `doesn’t exist` |
| Zendesk | `zendesk.com` | `Help Center Closed` |
| Cargo | `cargo.site` | unclaimed site page |
| Unbounce | `unbouncepages.com` | page not found |
| Surge | `surge.sh` | `project not found` |
| Bitbucket | `bitbucket.io` | `Repository not found` |
| Azure | `azurewebsites.net`, `cloudapp.azure.com` | 404 / app not found |
| AWS S3 | `s3.amazonaws.com`, `s3-website-*` | `NoSuchBucket` |
| CloudFront | `cloudfront.net` | distribution not configured |
| Netlify | `netlify.app` | `Not Found - Request ID` |
| Vercel | `vercel.app` | `DEPLOYMENT_NOT_FOUND` |
| Cloudflare Pages | `pages.dev` | project not found |
| Readme | `readme.io` | project not found |
| Statuspage | `statuspage.io` | page not found |
| UserVoice | `uservoice.com` | forum not found |
| Pingdom | `pingdom.com` | check not found |

Fingerprints decay. Treat a match as a **candidate**, not proof.

### 4. Wildcard check

Resolve several random labels:

```bash
for i in 1 2 3; do
  dig +short "doesnotexist-$RANDOM.example.com"
done
```

If every label resolves, the zone has wildcard DNS. Compare the wildcard
response with the suspected host. A wildcard alone is not a takeover.

### 5. CNAME-following verification risk

For a candidate, record:

- whether the provider's verification token is looked up at the CNAME target;
- whether the aliasing domain itself configures a token;
- whether the provider treats "token found after following CNAME" as proof.

This is a **risk annotation**, not an attempt to verify ownership. Do not
create a token, app, or record.

## Merge into swarmrecon

`16-takeover/takeover-candidates.tsv`:

```text
host  cname_chain  provider  fingerprint  http_status  final_url
confidence  wildcard  verification_model  evidence  manual_action
```

Add a short evidence file per candidate (headers + body excerpt + timestamp).
Feed the host into the manual queue, not into an automatic exploit step.

## Stop lines

- Do not register, claim, create, or publish anything.
- Do not create a bucket, app, site, repository, or DNS record.
- Do not use a provider's "claim" workflow.
- Do not probe provider APIs with credentials.
- Do not treat a provider 404 as proof; verify the DNS chain and the provider
  fingerprint.
- Do not scan a provider's shared infrastructure.

## Manual follow-up

- Confirm the DNS record is still delegated to the provider.
- Confirm the provider has no tenant for the name.
- Check whether cookies, OAuth redirect URIs, email, or CSP trust the name.
- Check whether the provider's verification follows CNAMEs.
- Record the business impact and the remediation owner.
- Remove or re-point the record; do not "test" the takeover by claiming it.

## Source notes

- Detectify, *Hostile subdomain takeover using Heroku/GitHub/Desk + more*.
- *Alias Equals Zone? Large-Scale and Stealthy Takeover of Domain Hosting
  Service via CNAME-Following Cross-Domain Verification* (ALIASLEAP).
- Web Hacking Techniques Index records 2 and 29.
