---
name: Certificate Transparency
description: Recon-only use of CT logs for hostname discovery, SAN expansion, issuance-time correlation, and lookalike inventory. Use when DNS or web links miss assets, or when certificates reveal related infrastructure.
---

# Certificate transparency

## Unique attack surface

Certificate Transparency logs are an append-only public record of publicly
trusted certificates. For recon they expose:

- hostnames that were issued but never linked from the web;
- SANs on shared and wildcard certificates;
- internal, staging, and legacy names that leaked into a public cert;
- issuance timestamps that cluster when one team or auto-renewal system
  manages many domains;
- lookalike, IDN, and typosquat certificates used for impersonation;
- certificate metadata (issuer, validity, serial) that links infrastructure.

The unique risk is **not the certificate itself**; it is the forgotten name or
related domain that the certificate proves exists. Discovery is passive.

## Signals worth chasing

- A CT name does not appear in `alive-domains.txt`.
- Many certificates share a `not_before` timestamp within seconds or minutes.
- A certificate covers a wildcard plus a set of specific names.
- A SAN points at a different apex or a brand lookalike.
- A certificate is issued by an unusual CA for the brand.
- A name has a valid certificate but no current DNS/HTTP response.
- A certificate includes an internal-looking name (`dev`, `staging`, `corp`,
  `vpn`, `admin`) or a non-standard TLD.
- A lookalike uses a homograph, hyphenation, or same-script skeleton that
  survives normalization.

## Safe collection

### 1. Pull CT records

Prefer structured JSON. `crt.sh` supports JSON output:

```bash
curl -sS --max-time 60 \
  'https://crt.sh/?q=%25.example.com&output=json' \
  -o ct-example.json
```

Keep the exact query and timestamp. A query for `%.example.com` includes
subdomains; use an exact query for the apex when needed.

Normalize each record:

```text
name_value  issuer_name  not_before  not_after  serial_number
entry_timestamp  source  query
```

`ctfr` is already Step 6. Add certificate metadata to its output rather than
replacing it.

### 2. Expand SANs

- Split multi-line `name_value` fields.
- Lowercase, strip trailing dots, IDNA-normalize.
- Drop wildcard `*` from the asset value but keep the wildcard flag.
- Add each in-scope name to the ledger with `source=ct`.
- Mark out-of-scope names `scope=out` and do not probe them.

### 3. Time-correlation clusters

Auto-renewing infrastructure often issues certificates for many domains at
the same moment. Build clusters by:

- `not_before` within a configurable window (start with 60 seconds);
- shared issuer;
- overlapping SAN sets;
- shared registrant/ASN/passive-DNS evidence, if available.

Treat a cluster as **related infrastructure candidates**, not proof of common
ownership. A shared CA timestamp can also be coincidence.

### 4. Lookalike inventory

Search CT for:

- suffix variants (`example.co`, `example.net`);
- hyphenation (`ex-ample.com`);
- character swaps and omissions;
- same-script confusables and IDN/punycode;
- brand + environment (`example-login`, `example-secure`);
- certificate SANs containing the brand in a subdomain of another apex.

`certgrep`-style regex/suffix/fuzzy queries are useful. Record the query and
the match; do not contact the lookalike.

### 5. Certificate validation metadata

For in-scope live hosts, optionally inspect the served chain:

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com \
  </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Record mismatches between the served certificate and the requested host, but
do not attempt to bypass validation.

## Merge into swarmrecon

- `06-ctfr/ct-certs.tsv`: one row per certificate/SAN.
- `06-ctfr/ct-clusters.json`: time/issuer/SAN clusters.
- `06-ctfr/lookalike-candidates.tsv`: lookalike inventory.
- Ledger: `type=cert` and `type=host`, `source=ct`.
- Compatibility files: only live, in-scope hosts.

## Stop lines

- Passive collection only; do not issue certificates.
- Do not register lookalike domains.
- Do not scan SAN hosts outside scope.
- Do not treat a CT name as live without DNS/HTTP verification.
- Do not use a certificate mismatch to attempt interception.
- Do not query private CT/log systems without authorization.

## Manual follow-up

- Why does a CT name have no DNS/HTTP presence?
- Is the name still owned, parked, or expired?
- Does a time cluster represent one team, one acquisition, or one provider?
- Does a lookalike certificate have a live phishing site?
- Are wildcard certificates scoped too broadly?
- Are internal names exposed in public SANs?

## Evidence format

```text
query  name  issuer  not_before  not_after  serial  source  cluster_id  scope  state
```

Keep the raw JSON response or a stable hash of it. Do not store private keys or
full certificate bodies unless needed.

## Source notes

- PT Security, *Discovering Domains via a Time-Correlation Attack on
  Certificate Transparency*.
- *Building certgrep.sh: a free certificate transparency search engine*.
- *Turning IDN edge cases into typosquats*.
- Web Hacking Techniques Index records 3, 4, and 47.
