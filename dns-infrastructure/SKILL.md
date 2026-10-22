---
name: DNS Infrastructure
description: Recon-only inventory of DNS records, delegation, wildcard behavior, address space, ASN, and reverse DNS. Use before HTTP probing to build the real host/IP/service map and avoid missing non-web infrastructure.
---

# DNS infrastructure

## Unique attack surface

DNS is both a discovery source and an attack surface. The recon-relevant
surface includes:

- `A`/`AAAA` addresses, including multiple addresses per name and IPv6-only
  services;
- `CNAME` chains, dangling tails, and CDN/origin splits;
- `NS` delegation, lame delegation, and zone-transfer exposure;
- `MX`, `TXT`, `SPF`, `DMARC`, `DKIM`, `CAA`, and `SRV` records that reveal
  mail, SaaS, verification, and service infrastructure;
- wildcard DNS that makes random labels look live;
- reverse DNS and ASN/netblock context for shared hosting and origin
  candidates;
- punycode/IDN and one-character variants that may be separate registrations;
- DNS resolver anomalies that affect whether a name is observable at all.

The goal is an **inventory with provenance**, not DNS cache poisoning or
resolver attacks.

## Signals worth chasing

- A host has more than one A/AAAA record, or IPv6 differs from IPv4.
- A CNAME points to a provider, a CDN, or a name that no longer resolves.
- `NS` records point at a provider that does not serve the zone (lame
  delegation).
- AXFR succeeds against an authoritative server (existing Step 10).
- `TXT` contains verification tokens for SaaS, cloud, or email providers.
- `MX` points at a mail provider not otherwise visible from the web.
- `CAA` restricts issuers, or is absent where certificates are issued.
- A wildcard answer is identical for every random label.
- Reverse DNS or ASN reveals a shared host/CDN rather than a dedicated origin.
- The same IP hosts many unrelated names (shared vhost surface).

## Safe collection

### 1. Record inventory

```bash
for t in A AAAA CNAME NS MX TXT SRV CAA SOA; do
  dig +short "$t" example.com
done

# Better batch output
dnsx -a -aaaa -cname -ns -mx -txt -resp -no-color \
  -l hosts.txt -o dnsx-records.txt
```

Keep the query time and resolver used. A negative answer from one resolver is
not proof of NXDOMAIN.

### 2. Zone transfer (authorized scope only)

```bash
dig AXFR example.com @ns1.example.com
```

Step 10 already does this. Record success/failure per nameserver. Do not retry
against unrelated nameservers or use AXFR as a denial-of-service vector.

### 3. Subdomain brute force

```bash
puredns bruteforce wordlists/subdomains-top1million-20000.txt example.com \
  -r wordlists/resolvers.txt \
  -w 08-puredns/puredns-subdomains.txt
```

Then resolve the results and merge them. Do not leave puredns output orphaned.

### 4. Wildcard detection

```bash
for i in 1 2 3 4 5; do
  dig +short "wildcard-test-$RANDOM.example.com"
done
```

If every name resolves, classify the zone as wildcard. Compare the answer set
and HTTP body before treating a discovered label as a real asset.

### 5. Address space and ASN

```bash
# Resolve, then enrich
dnsx -a -aaaa -resp -no-color -l hosts.txt -o resolved.txt
asnmap -i ips.txt            # if installed
whois <ip>
dig -x <ip>
```

For each unique IP record:

- ASN, organization, country;
- PTR;
- whether it is a CDN/WAF edge or a dedicated origin candidate;
- every hostname that resolves to it.

Do not scan a shared CDN range unless the IP/CIDR is explicitly in scope.

### 6. Typosquat / IDN inventory (passive)

- Generate same-script and cross-script skeletons.
- Check CT and passive DNS for registrations.
- Do not register, resolve, or contact lookalikes outside scope.

## Merge into swarmrecon

- All record types → `00-assets/assets.tsv` with `source=dns`.
- Host → IP edges → `00-assets/edges.tsv` (`resolves_to`).
- CNAME edges → `edges.tsv` (`cname_to`).
- Service inventory → `05-nmap/service.tsv`.
- Wildcard verdict → `02-dns-whois/wildcard.txt` and `coverage.json`.
- AXFR result → `10-zone-transfer/` and the manual queue.
- ASN/PTR → `02-dns-whois/asn.tsv`, `ptr.tsv`.

## Stop lines

- No DNS cache poisoning, resolver flooding, or amplification.
- No AXFR against nameservers outside scope.
- No brute force of third-party DNS zones.
- No scanning of shared CDN/cloud ranges without IP/CIDR scope.
- No lookalike registration or contact.
- No relying on a single resolver for a negative result.

## Manual follow-up

- Confirm multiple A/AAAA records are intentional.
- Review CNAME tails that no longer resolve.
- Review lame delegation and unused `NS`.
- Review `TXT` verification tokens for forgotten SaaS.
- Review `MX` and mail authentication records.
- Review wildcard DNS and whether it hides real labels.
- Review ASN/origin candidates with the asset owner.

## Evidence format

```text
query  type  value  resolver  timestamp  source  state  notes
```

Keep raw `dig`/`dnsx` output and the exact resolver used.

## Source notes

- Web Hacking Techniques Index record 31 (DNS silent vulnerabilities) is
  background only; this skill does not reproduce resolver attacks.
- CT and takeover skills consume the DNS map built here.
