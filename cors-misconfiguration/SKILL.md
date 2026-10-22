---
name: CORS Misconfiguration
description: Recon-only inventory of cross-origin resource sharing behavior. Use when an API or sensitive endpoint reflects arbitrary Origin headers, trusts subdomains, or allows credentials. Detection only; do not exfiltrate data.
---

# CORS misconfiguration

## Unique attack surface

CORS is a browser-enforced boundary. A misconfiguration lets an unrelated
origin read responses that should be restricted to the application's own
origins. The unique surface is:

- `Access-Control-Allow-Origin` (ACAO) reflection;
- `Access-Control-Allow-Credentials: true` (ACAC) combined with a reflected or
  wildcard origin;
- `Origin: null` acceptance;
- trust in any subdomain, including abandoned/takeover-prone ones;
- trust in HTTP origins, ports, or lookalike suffixes;
- preflight behavior for non-simple methods/headers;
- `Vary: Origin` missing, causing cache confusion;
- endpoints that return sensitive data without authentication but rely on CORS
  as the only boundary.

The objective is a **read-only inventory** of which origins are trusted and
which responses are exposed. Do not use a permissive policy to exfiltrate data.

## Signals worth chasing

- ACAO echoes an arbitrary `Origin` value.
- ACAO is `*` while ACAC is `true` (invalid in browsers, but a design smell).
- ACAO reflects `https://<random>.example.com`.
- ACAO reflects `null`.
- ACAO reflects an HTTP origin or a non-default port.
- ACAO reflects a suffix lookalike (`example.com.evil.tld`) or a prefix
  (`notexample.com`).
- `Vary: Origin` is missing on a dynamic ACAO response.
- Preflight allows credentials, arbitrary headers, or all methods.
- A sensitive endpoint returns data without auth and has a permissive policy.

## Safe collection

### 1. Baseline

Pick an in-scope endpoint that returns non-sensitive data, or a known API
endpoint. Record:

- request URL and method (GET/HEAD);
- response status and content type;
- ACAO, ACAC, `Access-Control-Allow-Methods`,
  `Access-Control-Allow-Headers`, `Access-Control-Expose-Headers`,
  `Vary`.

### 2. Bounded origin matrix

Send GET/HEAD with a small set of non-existent, non-resolving origins. Do not
send cookies or Authorization headers.

```bash
for origin in \
  "https://swarmrecon.invalid" \
  "https://sub.swarmrecon.invalid" \
  "null" \
  "http://swarmrecon.invalid"; do
  printf '\n=== %s ===\n' "$origin"
  curl -sS -D - -o /dev/null --max-time 15 \
    -H "Origin: $origin" \
    "https://app.example.com/api/me"
done
```

If the endpoint is in scope and the response is safe, repeat with an in-scope
subdomain origin to see whether subdomain trust is broad. Do not use a
takeover-prone subdomain as a test origin.

### 3. Preflight

Use `OPTIONS` only against an in-scope endpoint, with a harmless method/header:

```bash
curl -sS -D - -o /dev/null --max-time 15 -X OPTIONS \
  -H "Origin: https://swarmrecon.invalid" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: content-type" \
  "https://app.example.com/api/me"
```

Record whether the preflight allows credentials, methods, and headers.

### 4. Classification

| Pattern | Meaning | Confidence |
|---|---|---|
| ACAO reflects arbitrary origin + ACAC true | High-risk read access if response is sensitive | high |
| ACAO reflects arbitrary origin, no ACAC | Public data or non-credentialed read | medium |
| ACAO `null` + ACAC true | Sandboxed/null-origin trust | high |
| ACAO reflects any subdomain + ACAC true | Subdomain takeover impact | high |
| ACAO reflects suffix/prefix lookalike | Boundary bug | high |
| ACAO `*`, no ACAC | Public by design unless data is sensitive | low |

Do not promote a finding without checking whether the response actually
contains non-public data.

## Merge into swarmrecon

```text
17-js-api-cloud/cors.tsv
url  method  origin_tested  acao  acac  vary  preflight  sensitivity  confidence  evidence
```

Ledger type: `api` or `url`. Edge: `trusts_origin` if you model it.

## Stop lines

- Do not send cookies or Authorization headers in a cross-origin test.
- Do not exfiltrate, store, or display sensitive response bodies.
- Do not use a real attacker-controlled domain; use reserved/invalid names.
- Do not test takeover-prone subdomains as trusted origins.
- Do not exploit a permissive policy beyond a minimal read-only check.
- Do not fuzz origins at scale.

## Manual follow-up

- Does the endpoint return user-specific data?
- Is ACAC true, and does the browser actually send credentials?
- Is `Vary: Origin` present?
- Does the app trust all subdomains, including dangling ones?
- Is `null` accepted?
- Is the policy intentional for a public API?

## Source notes

- Outpost24, *CORS vulnerabilities: Weaponizing permissive CORS
  configurations* (discovery half only).
- Web Hacking Techniques Index record 34.
