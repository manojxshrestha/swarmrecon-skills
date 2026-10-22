---
name: Cloud Storage and BaaS
description: Recon-only inventory of S3/GCS/Azure/R2 buckets, Supabase, Firebase, and deployment platforms. Use when JS, DNS, or hostnames point at cloud storage or a backend-as-a-service.
---

# Cloud storage and BaaS

## Unique attack surface

Cloud storage and backend-as-a-service projects expose a different trust
boundary from the website:

- bucket names and object namespaces;
- public listing, public objects, and per-object ACLs;
- CORS and signed-URL behavior;
- CDN/CloudFront/R2 custom domains;
- Supabase project URLs, `anon` keys, RLS policies, and exposed tables;
- Firebase project config, auth domains, and database URLs;
- deployment platforms (Cloudflare Pages, Netlify, Vercel) with preview and
  production hosts;
- build artifacts and source maps hosted on the platform.

The unique risk is **public configuration that reveals data or an
authorization boundary**, not the cloud provider itself. Detection must be
read-only and minimal.

## Signals worth chasing

- CNAME to `s3.amazonaws.com`, `s3-website-*`, `cloudfront.net`,
  `storage.googleapis.com`, `blob.core.windows.net`, `r2.dev`,
  `pages.dev`, `netlify.app`, `vercel.app`.
- `Server: AmazonS3`, `x-amz-request-id`, `x-amz-id-2`, `x-amz-bucket-region`.
- `NoSuchBucket`, `AccessDenied`, `ListBucketResult`, `PermanentRedirect`.
- `x-goog-*`, `x-ms-*`, `x-guploader-uploadid`.
- `supabaseUrl`, `supabaseKey`, `anon` JWT, `*.supabase.co`.
- `firebaseConfig`, `*.firebaseio.com`, `*.firebaseapp.com`,
  `identitytoolkit.googleapis.com`.
- `*.pages.dev`, `*.netlify.app`, `*.vercel.app`, and preview/branch hosts.
- Bucket-like strings in JS: `assets`, `static`, `media`, `cdn`, `backup`,
  `dev`, `staging`, `prod`, company name, product name.

## Safe collection

### 1. Candidate generation

Build a small, bounded list from:

- apex and subdomain labels;
- JS strings and source maps;
- DNS CNAME targets;
- common prefixes and environment suffixes.

Do not generate thousands of random bucket names. A short, evidence-driven
list is enough for recon.

### 2. DNS and HTTP metadata

```bash
dig +short CNAME assets.example.com
curl -sS -I --max-time 15 https://assets.example.com/
curl -sS --max-time 15 https://candidate-bucket.s3.amazonaws.com/
```

Record:

- status and provider headers;
- `NoSuchBucket` vs `AccessDenied` vs `ListBucketResult`;
- region/endpoint;
- whether a custom domain hides the bucket.

A single unauthenticated metadata request is the limit. Do not download
objects.

### 3. Public listing check (minimal)

If the response advertises a public listing, request at most one page with a
tiny `max-keys`, and record only the fact and the first key prefix:

```bash
curl -sS --max-time 15 \
  'https://candidate-bucket.s3.amazonaws.com/?list-type=2&max-keys=1'
```

Do not iterate, download, or mirror objects. If the listing contains personal
data, stop and report the exposure; do not collect it.

### 4. Supabase

From JS/config, extract:

- project URL (`https://<project>.supabase.co`);
- `anon` key presence;
- JWT header/payload metadata (`ref`, `role`, `exp`) by decoding only, never
  using the key;
- storage bucket names;
- auth providers.

Do not query tables, call RPCs, or use the anon key. RLS review is manual and
requires authorization.

### 5. Firebase

Extract public config and record:

- project ID;
- auth domain;
- database URL;
- storage bucket;
- whether the config is expected to be public (it usually is).

Do not attempt writes or auth bypass. Public config alone is not a finding;
the finding is an exposed data path or misconfigured rule.

### 6. Deployment platforms

- Identify production and preview hosts.
- Check whether preview deployments are protected.
- Look for source maps, build manifests, and stale deployments.
- Do not brute-force preview URLs at scale.

## Merge into swarmrecon

```text
17-js-api-cloud/cloud-assets.tsv
provider  asset  type  evidence  public_indicator  scope  confidence  manual_action
```

Ledger types: `bucket`, `url`, `host`, `api`. Edges: `hosts_bucket`,
`references`, `same_host`.

## Stop lines

- No writes, ACL changes, uploads, or bucket creation.
- No object downloads or listing iteration.
- No Supabase table/RPC queries, no key use.
- No Firebase writes or auth attempts.
- No bucket-name brute force beyond the evidence-driven candidate list.
- No scanning cloud provider shared ranges.
- If data is exposed, stop collecting and report the minimum evidence.

## Manual follow-up

- Is the bucket intended to be public?
- Does the public listing expose PII, backups, or source?
- Is the Supabase `anon` key expected, and are RLS policies enforced?
- Is the Firebase config expected, and are rules restrictive?
- Are preview deployments protected?
- Are source maps/build artifacts intentionally public?

## Source notes

- Detectify, *A deep dive into AWS S3 access controls*.
- SupaPwn and the 2026 Supabase security study.
- Cloudflare Pages research.
- Truffle Security cloud-dev-environment and secret research.
- Web Hacking Techniques Index records 18–22.
