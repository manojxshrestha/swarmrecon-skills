---
name: Hidden HTTP Surface
description: Recon-only review of vhosts, reverse proxies, alternate ports, TLS SNI, and Host-header authority disagreements. Use after DNS/service inventory when a host may expose more than its default web root.
---

# Hidden HTTP surface

## Unique attack surface

The visible website is often one tenant of a shared reverse proxy, CDN, load
balancer, or origin. The hidden surface is the set of **other names, ports,
protocols, and authority values** that the same infrastructure accepts:

- virtual hosts on a shared IP that are not in public DNS;
- alternate HTTP ports (`8080`, `8443`, `8000`, `8888`, etc.);
- HTTP vs HTTPS, HTTP/1.0 vs HTTP/1.1, and TLS SNI mismatches;
- proxy/CDN layers that interpret `Host`, `X-Forwarded-Host`, `Forwarded`, or
  `:authority` differently from the application;
- default vhosts, admin panels, health endpoints, and internal-only apps that
  happen to be reachable from the edge;
- cache/proxy metadata (`Via`, `X-Cache`, `Age`, `CF-Cache-Status`,
  `Server-Timing`) that reveals an intermediate layer.

This is the surface described by *Cracking the Lens* and *Poisoned by the
Host*. The goal is to **find and describe** the layer, not to exploit it.

## Signals worth chasing

- Same IP, different `Host` → different status, title, body length, redirect,
  cookie domain, or `Server`.
- A random non-existent `Host` gets a default page, but a guessed vhost does
  not.
- `400`, `421`, `404`, or `403` on the apex but `200` on an alternate name.
- TLS certificate CN/SAN does not match the requested hostname.
- `Server`, `X-Powered-By`, `Via`, `X-Cache`, `X-Served-By`, `Age`,
  `CF-Cache-Status`, `Server-Timing`, or `Alt-Svc` changes across variants.
- A port accepts TCP but returns no HTTP; another port requires SNI.
- Reverse DNS, ASN, or CNAME suggests a CDN/origin split.
- Multiple hostnames resolve to the same IP but only one is in `https-subs.txt`.

## Safe collection

### 1. Build the host/IP/port map

Use the ledger, then verify:

```bash
# A/AAAA + CNAME map
dnsx -a -aaaa -cname -resp -no-color -l hosts.txt

# Reverse DNS and ASN enrichment (if installed)
dnsx -ptr -resp -no-color -l ips.txt

# HTTP probe across likely ports; keep tech/server/title
httpx -l hosts.txt -ports 80,443,8080,8443,8000,8888 \
  -status-code -title -tech-detect -web-server -no-color \
  -o http-probe.txt
```

For a specific host-to-IP pair, preserve Host and SNI explicitly:

```bash
curl --resolve app.example.com:443:203.0.113.10 \
  -sS -D - -o /dev/null https://app.example.com/
```

Do not scan every address of a shared CDN. Use one representative edge unless
the IP/CIDR is explicitly in scope and `--scan-all-ips` is approved.

### 2. Establish a baseline

For each `scheme://host:port`:

- request the normal URL;
- request a random non-existent vhost name;
- record status, headers, body hash, title, `Location`, content length, and
  any reflected host value.

A random baseline is essential: a 404 page with a stable content length is not
a hidden vhost.

### 3. Bounded vhost pass

```bash
ffuf -w vhost-labels.txt:FUZZ \
  -u https://app.example.com/ \
  -H "Host: FUZZ.example.com" \
  -H "User-Agent: Mozilla/5.0 ..." \
  -fs <baseline-length> -fc 400 \
  -mc all -rate 5 -of json -o vhosts.json
```

Filter the wordlist to legal single DNS labels. Test the same label set over
HTTPS and over any alternate port that serves HTTP. Do not reuse a path
wordlist as a vhost list without filtering.

### 4. Host-authority matrix (opt-in, safe mode)

Only after `--host-probe` is explicitly enabled:

| Variant | Purpose | Guard |
|---|---|---|
| `Host: <random>.<domain>` | default vhost baseline | never a third-party domain |
| `Host: <ip>` | IP-based routing | only the in-scope IP |
| `Host: localhost` | default/local vhost | GET/HEAD only; no internal target |
| `X-Forwarded-Host: <random>` | proxy trust | same in-scope host |
| `Forwarded: host=<random>` | RFC 7239 parsing | same in-scope host |
| absolute-form target | proxy request-target parsing | same in-scope host |
| HTTP/1.0 | protocol downgrade behavior | GET/HEAD only |

Record response differences. Do **not** use OAST hostnames, internal IPs, or
metadata addresses. Do **not** attempt request smuggling, cache poisoning, or
cache deception.

### 5. Protocol and cache observations

- Compare `http://` and `https://` responses.
- Check `Alt-Svc`, `Vary`, `Cache-Control`, `Age`, `X-Cache`, and
  `CF-Cache-Status`.
- Note whether the response appears to be served by an edge, an origin, or a
  default backend.
- Record the evidence; do not try to poison the cache.

## Merge into swarmrecon

- New hosts and `scheme://host:port` combinations → `00-assets/assets.tsv`.
- Vhost hits → `09-vhost/` and `15-host-surface/vhosts.tsv`.
- Host matrix → `15-host-surface/host-matrix.tsv`.
- Proxy/cache observations → `15-host-surface/proxy-headers.tsv`.
- Live hosts → compatibility `alive-domains.txt` / `https-subs.txt`.
- High-value vhosts → Step 14 target list and the manual queue.

## Stop lines

- No `Host` values pointing at internal IPs, `169.254.169.254`, link-local
  addresses, or third-party domains.
- No OAST/callback payloads by default.
- No request smuggling, cache poisoning, cache deception, or SSRF attempts.
- No state-changing methods.
- No brute force of shared CDN addresses.
- If a variant causes a redirect to an internal or third-party host, record
  the redirect and stop; do not follow it.

## Manual follow-up

Ask a human to review:

- vhosts with `200` and a distinct app shell;
- hosts that only appear over HTTPS/SNI or an alternate port;
- responses that reflect the supplied host into links, cookies, or redirects;
- proxy headers that indicate an unexpected intermediary;
- default pages that expose product/version/admin paths.

## Evidence format

```text
host  port  scheme  variant  status  location  title  body_sha256  server  via  cache  source  confidence
```

Keep the exact request headers (with secrets removed), timestamp, and the
baseline used for comparison.

## Source notes

- James Kettle, *Cracking the Lens: Targeting HTTP's Hidden Attack-Surface*.
- *Poisoned by the Host: Large-Scale Measurement of Host Name Poisoning in Web
  Applications* (HALO).
- Web Hacking Techniques Index records 1 and 30.
