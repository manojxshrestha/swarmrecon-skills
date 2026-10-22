---
name: swarmrecon Attack Surface Index
description: Index and operating rules for the recon-only attack-surface skills that accompany swarmrecon. Load the specific category skill when reviewing a target.
disable-model-invocation: true
---

<h1 align="center">
  <br>
  swarmrecon skills
  <br>
</h1>

<h4 align="center">Recon-only OpenCode guides for mapping attack surface — DNS · CT · APIs · JavaScript · cloud · identity · mobile</h4>

<p align="center">
  <img src="https://img.shields.io/badge/OpenCode-skills-111827" alt="OpenCode skills">
  <img src="https://img.shields.io/badge/skills-15-blue" alt="15 skills">
  <img src="https://img.shields.io/badge/mode-recon--only-0f766e" alt="Recon only">
  <img src="https://img.shields.io/badge/setup-one%20command-orange" alt="One-command setup">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license">
</p>

<p align="center">
  A curated set of <b>15 OpenCode skills</b> for reviewing a web target's
  attack surface without turning reconnaissance into exploitation.
  Each skill is a Markdown guide with a clear scope, safe collection steps,
  evidence rules, and explicit stop lines.
</p>

<p align="center">
  <b>Collection companion:</b>
  <a href="https://github.com/manojxshrestha/swarmrecon">https://github.com/manojxshrestha/swarmrecon</a>
</p>

---

**Quick links:** [What is this?](#what-is-this) · [Quick start](#quick-start) · [Setup guide](#setup-guide) · [Using the guides](#using-the-guides-in-opencode) · [Skill catalog](#skill-catalog) · [swarmrecon integration](#swarmrecon-integration) · [Safety model](#safety-model) · [Repository layout](#repository-layout) · [Development](#development) · [Troubleshooting](#troubleshooting) · [swarmrecon ↗](https://github.com/manojxshrestha/swarmrecon)

---

> [!IMPORTANT]
> **Recon only.** These skills describe discovery, inventory, and evidence
> collection. They do **not** authorize exploitation, authentication attempts,
> credential testing, host-header SSRF, OAST callbacks, or takeover claims.
> Use them only inside an explicit scope and rules of engagement.

---

## What is this?

[`swarmrecon`](https://github.com/manojxshrestha/swarmrecon) automates the
collection half of a reconnaissance workflow. This repository covers the
interpretation half: one OpenCode skill per attack-surface category, so an
OpenCode session can load the right mental model before it touches a target.

Each skill answers the same questions:

1. What is the unique attack surface of this category?
2. Which signals make it worth a human look?
3. What safe, read-only collection steps are appropriate?
4. How do findings map into the `swarmrecon` asset ledger?
5. Where is the line between recon and exploitation?
6. What evidence should a reviewer preserve?

The skills are intentionally **not** an exploit cookbook. They are a review
framework for scope-aware, evidence-driven reconnaissance.

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/manojxshrestha/swarmrecon-skills.git ~/skills
cd ~/skills

# 2. Validate the skills and register them with OpenCode
./setup.sh

# 3. Restart OpenCode, then load a skill by ID
#    Example prompt:
#    Use the `dns-infrastructure` skill to review example.com.
```

`setup.sh` validates every `SKILL.md`, backs up the existing OpenCode config,
and adds this repository to its `skills` array without removing other settings.

---

## Setup guide

### Requirements

| Requirement | Why |
|---|---|
| [OpenCode](https://opencode.ai/) | Loads and runs the skills |
| `bash` 4+ | Runs `setup.sh` |
| `python3` | Safely merges the OpenCode JSON config |
| `git` | Clone and update this repository |
| [`swarmrecon`](https://github.com/manojxshrestha/swarmrecon) *(optional)* | Collection companion for the review workflow |

### Automatic setup

```bash
git clone https://github.com/manojxshrestha/swarmrecon-skills.git ~/skills
cd ~/skills
./setup.sh
```

Expected shape:

```text
[*] swarmrecon OpenCode skills — setup
[*] Skills directory: /home/you/skills
[+] Validated 15 skills
[+] OpenCode: <version>
[+] added skills entry: ~/skills
[+] OpenCode config: /home/you/.config/opencode/opencode.json
[+] Restart OpenCode to reload the skills.
[+] Setup complete.
```

### What `setup.sh` does

- Finds every `<skill-id>/SKILL.md` and checks its YAML frontmatter.
- Reads `~/.config/opencode/opencode.json` (or `$OPENCODE_CONFIG`).
- Preserves all existing config keys and existing skill paths.
- Adds this repository to the `skills` array exactly once.
- Creates a timestamped backup before changing an existing config.
- Refuses to overwrite invalid JSON.
- Prints a clear next step instead of guessing.

### Setup options

| Option | Meaning |
|---|---|
| `--config <path>` | Use a custom OpenCode config file |
| `--dry-run` | Validate and show the planned change without writing |
| `--check` | Exit `0` only when this repository is registered |
| `--print-config` | Print a minimal config snippet and exit |
| `--no-config` | Validate the skills only; do not touch OpenCode config |
| `-h, --help` | Show help |

Examples:

```bash
./setup.sh --dry-run
./setup.sh --config ~/.config/opencode/opencode.json
./setup.sh --check
./setup.sh --no-config
```

### Manual setup

If you prefer to edit the config yourself, add this repository to
`~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["~/skills"]
}
```

If the file already exists, append the path to the existing `skills` array:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": [
    "~/other-skills",
    "~/skills"
  ]
}
```

Use an absolute path if your OpenCode version does not expand `~`.

### Verify the setup

```bash
./setup.sh --check
```

Then restart OpenCode. The skill IDs in the [catalog](#skill-catalog) should be
available in a new session.

### Update the skills

```bash
git -C ~/skills pull --ff-only
./setup.sh --check
```

### Remove the skills

Remove this repository's path from the `skills` array in the OpenCode config,
then delete the clone if it is no longer needed. The setup script does not
modify any other config keys.

---

## Using the guides in OpenCode

These are OpenCode **skills**, not standalone shell scripts. OpenCode reads the
YAML frontmatter in each `SKILL.md`, discovers the skill by ID, and loads the
body as the guide when you select it.

### Load one skill

Mention the skill name in the prompt, or load it through the `skill` tool when
your client exposes one:

```text
Use the `dns-infrastructure` skill to review example.com.
Follow its safe collection steps and stop lines, and return the evidence table.
```

### Chain a review

Load one surface at a time. A staged review can chain the guides without turning
them into an exploit run:

```text
For example.com, use `dns-infrastructure`, then
`certificate-transparency`, then `subdomain-takeover`.
Keep everything recon-only, cite the source for every finding, and stop before
any takeover claim or credential test.
```

### Pair with swarmrecon

[`swarmrecon`](https://github.com/manojxshrestha/swarmrecon) performs
collection; these skills tell OpenCode how to interpret and prioritize the
results. A typical loop is:

```bash
./swarmrecon.sh -d example.com
```

Then ask OpenCode to use the relevant skill against `recon/example.com/`:

```text
Use the `api-surface` skill on the crawl output in recon/example.com/.
Map API endpoints and object references, mask any secrets, and do not fuzz or
attempt authentication.
```

### Operating rules

- Load the category skill **before** running commands.
- Keep the target inside the authorized scope.
- Prefer one surface at a time; do not run every guide as one giant scan.
- Treat the skill as a review lens, not permission for exploitation.
- Preserve source, timestamp, and command context for every finding.
- Mask secrets and never validate or use them.
- State what was **not** tested.

---

## Skill catalog

| Skill | Unique surface | Start when |
|---|---|---|
| `dns-infrastructure` | DNS records, delegation, wildcard behavior, ASN, reverse DNS | You have a domain and need the complete DNS/service map |
| `certificate-transparency` | Hostnames, SANs, issuance clusters, lookalike certificates | DNS and web links miss assets |
| `subdomain-takeover` | Dangling CNAMEs and unclaimed hosted-service names | You have CNAMEs and hosted-service records |
| `hidden-http-surface` | Reverse proxies, vhosts, alternate ports, host-authority disagreement | You have live hosts/IPs and want vhosts or proxy behavior |
| `javascript-sourcemaps` | Client bundles and source maps as endpoint/secret maps | You have crawled JavaScript or source maps |
| `api-surface` | GraphQL, tRPC, OpenAPI, REST, gRPC-Web, WebSocket, object references | You have endpoints, schemas, or API-like routes |
| `cors-misconfiguration` | Reflected origins, credentials, `null`, subdomain trust | You have an API and need to map cross-origin trust |
| `cloud-storage-baas` | S3/GCS/Azure/R2, Supabase, Firebase, deployment platforms | JavaScript, DNS, or hostnames point at cloud storage or a BaaS |
| `secret-exposure` | Credentials and configuration in public artifacts | You have public JS, maps, repos, CI files, backups, or image metadata |
| `content-discovery` | Unlinked paths, backups, VCS metadata, API docs, framework routes | You need assets the crawl did not link |
| `archive-osint` | Historical URLs, passive DNS, forgotten hosts | Current crawl data is thin or historical assets may still exist |
| `source-code-vcs` | Exposed source control, config, backups, Perforce, CI | `.git`, backups, or source-disclosure paths are reachable |
| `identity-oauth` | OAuth/OIDC, SAML, SSO, client IDs, redirect URIs, scopes, tenants | The target has login/SSO or references an identity provider |
| `framework-routes` | Next.js, React, Gatsby, Nuxt, SvelteKit, Astro, Remix, Angular, Vue, WordPress, Laravel, Spring, ASP.NET | Technology detection shows a framework |
| `mobile-api` | Hidden or legacy APIs and hardcoded config in local APK/IPA files | A mobile app exists and the web surface looks incomplete |

---

## Recommended review order

Use the order as a menu, not a mandate. Load only what the current evidence
justifies.

| Phase | Skills | Goal |
|---|---|---|
| 1. Map the estate | `dns-infrastructure` → `certificate-transparency` → `subdomain-takeover` | Domains, certificates, delegation, dangling infrastructure |
| 2. Map the live edge | `hidden-http-surface` → `framework-routes` → `content-discovery` | Hosts, vhosts, proxies, framework routes, unlinked paths |
| 3. Map the application | `javascript-sourcemaps` → `api-surface` → `cors-misconfiguration` | Bundles, endpoints, schemas, object references, cross-origin trust |
| 4. Map the supporting surface | `cloud-storage-baas` → `secret-exposure` → `source-code-vcs` | Buckets, BaaS, public artifacts, source disclosure |
| 5. Map the identity and mobile edge | `identity-oauth` → `mobile-api` | SSO/OIDC/SAML inventory and local mobile API surface |
| 6. Recover history | `archive-osint` | Historical URLs and forgotten hosts with provenance |

The catalog is intentionally ordered by discovery confidence: infrastructure
first, then live HTTP, then application and identity surfaces.

---

## swarmrecon integration

Keep the existing 1–14 step numbering and install paths. New collection fits
into the current tree:

| Skill | Existing step | Proposed output |
|---|---|---|
| `dns-infrastructure` | 2, 5, 10 | `00-assets/`, `05-nmap/service.tsv` |
| `certificate-transparency` | 6 | `06-ctfr/ct-certs.tsv`, `ct-clusters.json` |
| `subdomain-takeover` | 16 (new) | `16-takeover/takeover-candidates.tsv` |
| `hidden-http-surface` | 9 + 15 (new) | `15-host-surface/` |
| `javascript-sourcemaps` | 13 + 17 (new) | `17-js-api-cloud/js/` |
| `api-surface` | 13, 14 + 17 | `17-js-api-cloud/endpoints.tsv` |
| `cors-misconfiguration` | 13 + 17 | `17-js-api-cloud/cors.tsv` |
| `cloud-storage-baas` | 17 | `17-js-api-cloud/cloud-assets.tsv` |
| `secret-exposure` | 13, 14 + 17 | `17-js-api-cloud/secrets-redacted.tsv` |
| `content-discovery` | 11, 14 | `14-high-value/`, `directories/<host>/` |
| `archive-osint` | 13 | `13-crawl/archive-urls.tsv` |
| `source-code-vcs` | 5, 14, 20 (new) | `20-source-vcs/exposure.tsv` |
| `identity-oauth` | 18 (new) | `18-identity/endpoints.tsv` |
| `framework-routes` | 1, 14 | `01-wappalyzer/framework-routes.tsv` |
| `mobile-api` | 19 (new) | `19-mobile/endpoints.tsv` |

`00-assets/` is the source of truth. Existing root files remain compatibility
views:

- `alive-domains.txt` — every live bare host from all sources;
- `https-subs.txt` — every live HTTPS URL from all sources;
- `targets.tsv` — scheme/host/port combinations, with SNI and source.

See the [swarmrecon guide](https://github.com/manojxshrestha/swarmrecon) for the
full pipeline and output layout.

---

## Evidence model

Every skill should emit rows compatible with `00-assets/assets.tsv`:

```text
asset_id  type  value  parent_id  source  first_seen  last_seen  state  confidence  scope  evidence
```

Useful `type` values: `domain`, `host`, `ip`, `url`, `js`, `api`, `bucket`,
`cert`, `service`, `mobile_endpoint`, `secret`.

Useful `state` values: `new`, `live`, `dead`, `nxdomain`, `filtered`,
`out_of_scope`, `candidate`.

Never write a full secret, token, cookie, or credential into the ledger. Use
`type=secret`, a location, a detector name, and a masked value.

### Definition of done

A category review is complete when:

1. the unique surface is enumerated, not just the obvious paths;
2. every finding has source/provenance and a timestamp;
3. liveness and scope are checked before a finding is promoted;
4. secrets are masked and never used;
5. the manual queue says what a human should verify and why;
6. the report states what was **not** tested.

---

## Safety model

- **Recon only.** No exploitation, authentication attempts, default
  credentials, password spraying, credential stuffing, or destructive methods.
- **Scope first.** Exact host boundary, explicit IP/CIDR for network scans.
  Reject private, loopback, link-local, multicast, and metadata addresses.
- **No OAST by default.** No callback payloads that could trigger SSRF or
  third-party interaction.
- **No host-header SSRF.** Do not send `Host` values pointing at internal
  addresses, metadata services, or third-party domains.
- **No writes.** Do not create buckets/apps/repos, claim takeover targets, or
  publish packages.
- **No secret use or validation.** Detect, redact, report, stop.
- **Respect infrastructure.** Conservative rate limits; do not scan shared CDN
  addresses without explicit IP/CIDR scope.
- **Edited evidence.** Keep timestamps, source, and command/URL context; do not
  paraphrase a finding into something stronger than the evidence.

If a technique in a source writeup is exploitation-only, this repository keeps
only the **discovery** half. The writeup is a map, not a permission slip.

---

## Repository layout

```text
swarmrecon-skills/
├── README.md                 # this index and operating guide
├── setup.sh                  # validate + register with OpenCode
├── LICENSE                   # MIT
├── api-surface/
│   └── SKILL.md
├── archive-osint/
│   └── SKILL.md
├── certificate-transparency/
│   └── SKILL.md
├── cloud-storage-baas/
│   └── SKILL.md
├── content-discovery/
│   └── SKILL.md
├── cors-misconfiguration/
│   └── SKILL.md
├── dns-infrastructure/
│   └── SKILL.md
├── framework-routes/
│   └── SKILL.md
├── hidden-http-surface/
│   └── SKILL.md
├── identity-oauth/
│   └── SKILL.md
├── javascript-sourcemaps/
│   └── SKILL.md
├── mobile-api/
│   └── SKILL.md
├── secret-exposure/
│   └── SKILL.md
├── source-code-vcs/
│   └── SKILL.md
└── subdomain-takeover/
    └── SKILL.md
```

---

## Development

### Add a skill

1. Create `<skill-id>/SKILL.md`.
2. Add YAML frontmatter with a unique `name` and a specific `description`.
3. Keep the body recon-only: scope, signals, safe collection, evidence, stop
   lines, and manual follow-up.
4. Run `./setup.sh --no-config` to validate the frontmatter and file layout.
5. Open a pull request with the new skill and a short rationale.

### Skill frontmatter

```yaml
---
name: Example Surface
description: Recon-only inventory of ... Use when ...
---
```

OpenCode uses the `name` and `description` to discover the skill. The body is
loaded only when the skill is selected.

### Review checklist

- Is the surface genuinely distinct from the other skills?
- Are the collection steps read-only and rate-conscious?
- Does every finding have provenance?
- Are secrets always masked?
- Is the stop line explicit?
- Does the skill say what **not** to test?

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `python3 not found` | Install Python 3, or add the `skills` entry manually |
| `invalid JSON in .../opencode.json` | Fix the config first; `setup.sh` will not overwrite it |
| Skill does not appear in OpenCode | Run `./setup.sh --check`, then restart OpenCode |
| Wrong skills directory | Run `./setup.sh --print-config` and compare the path |
| Existing config was changed unexpectedly | Restore the timestamped `.bak.*` file created by `setup.sh` |
| `opencode` not found | Install OpenCode, then re-run `./setup.sh` |
| Skill fires too broadly | Load one skill explicitly and state the target surface in the prompt |

---

## Source anchors

The skills are derived from the Web Hacking Techniques Index
(<https://webhacklist.com/>) and the 47 recon-relevant records reviewed while
building this skill set. Key anchors:

- Cracking the Lens: hidden HTTP surface and host-header authority.
- Detectify: hostile subdomain takeover.
- PT Security: CT time correlation.
- certgrep / Have I Been Squatted: CT search and IDN/lookalike inventory.
- WARDroid and mobile super-app research: hidden mobile APIs.
- Doyensec GraphQL, tRPC research, OpenAPI deep dive, VOAPI2, gRPC-Web:
  API surface.
- Assetnote static-site-generator research, Next.js middleware/React2Shell:
  framework routes and build artifacts.
- Detectify S3, SupaPwn/Supabase study, Cloudflare Pages: cloud/BaaS surface.
- Truffle Security: public-secret exposure, PNG metadata, cloud dev envs.
- P4WNED: Perforce/source-control exposure.
- Detectify/ASP.NET source disclosure: VCS and config exposure.
- Fuzzuli: domain-derived wordlists.
- Archive-integrity research: historical URLs as clues, not truth.
- AliasLeap and Host Name Poisoning: verification and host-authority risks.
- OAuth client-ID spoofing: identity inventory boundary (manual only).
- Dependency confusion / CI worm: supply-chain inventory.

---

## License

MIT — see [LICENSE](LICENSE).

Use these guides only on systems you own or have explicit written authorization
to test.
