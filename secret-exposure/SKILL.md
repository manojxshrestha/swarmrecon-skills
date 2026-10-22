---
name: Secret Exposure
description: Recon-only detection of credentials and configuration in public artifacts such as JS bundles, source maps, repositories, CI files, backups, and image metadata. Use detector output as a lead, never as a credential to use.
---

# Secret exposure

## Unique attack surface

A secret does not have to be in a database to be exposed. Public artifacts
often contain:

- API keys, tokens, JWTs, private keys, and connection strings;
- cloud credentials and bucket names;
- CI/CD secrets, deployment tokens, and webhook URLs;
- internal hostnames, database URLs, and admin endpoints;
- AI-workflow prompts, file paths, and keys embedded in PNG/JPEG metadata;
- deleted or forked repository data that remains reachable;
- cloud development environments and package registries.

The unique risk is **the blast radius of a public artifact**, not the artifact
itself. The skill is detection and redaction, not validation.

## Signals worth chasing

- Detector hits from `trufflehog` or `gitleaks`.
- High-entropy strings near names like `key`, `secret`, `token`, `password`,
  `private`, `credential`, `auth`.
- Known prefixes: `AKIA`, `ASIA`, `AIza`, `ghp_`, `github_pat_`, `xoxb-`,
  `sk_live_`, `pk_live_`, `eyJ` (JWT), `-----BEGIN ... PRIVATE KEY-----`.
- Connection strings: `postgres://`, `mysql://`, `mongodb://`, `redis://`.
- Cloud config: `aws_access_key_id`, `aws_secret_access_key`, `GOOGLE_`,
  `AZURE_`, `SUPABASE_`, `FIREBASE_`.
- CI files: `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`,
  `bitbucket-pipelines.yml`, `.circleci/`.
- Image metadata: `exiftool` fields containing prompts, paths, or keys.
- Public package manifests and lockfiles with private registry URLs.

## Safe collection

### 1. Scan downloaded public artifacts

```bash
# JS, source maps, JSON, text, config, backups
trufflehog filesystem --no-verification --json \
  js/ 13-crawl/ 14-high-value/ > secrets-trufflehog.jsonl

# A source tree or cloned public repository
gitleaks detect --no-git --source ./public-repo --report-format json \
  --report-path secrets-gitleaks.json
```

`--no-verification` is important: do not make network calls to validate a key.
If a detector insists on verification, disable it or skip that detector.

### 2. Scan public repositories carefully

- Discover org/repo links from the site, `security.txt`, package manifests, and
  source maps.
- Use public APIs only (`gh api`, public Git hosts).
- Clone only public repositories, with a shallow clone and a size cap.
- Scan the working tree and public history.
- Do not access private repos, deleted objects, or fork-network data that
  requires authentication.

```bash
gh repo list <org> --limit 100 --json name,url,visibility
git clone --depth 1 https://github.com/<org>/<repo>.git public-repo/
```

### 3. Package and CI inventory

- Parse `package.json`, lockfiles, `requirements.txt`, `pom.xml`,
  `build.gradle`, `go.mod`, `Gemfile`.
- Record private registry URLs and scoped package names.
- Do not publish a package, claim a scope, or run install scripts.
- Review CI files for secret names and deployment targets, not for exploitation.

### 4. Image metadata

```bash
exiftool -json image.png > image-metadata.json
```

Look for prompts, file paths, workflow names, and keys. Do not redistribute the
image or the metadata.

### 5. Error pages and backups

- Stack traces can reveal paths, versions, and environment variables.
- Backup/config files may contain credentials.
- Treat any hit as sensitive; store only a masked value and location.

## Redaction rules

Store:

```text
type  detector  location  masked_value  confidence  first_seen  source
```

Masking examples:

- `AKIA...` → `AKIA…LAST4`;
- `ghp_...` → `ghp_…LAST4`;
- JWT → header/payload metadata only, no signature;
- private key → detector + path only.

Never write the full value to `recon.log`, `README`, commit messages, or a
report that may be shared. Keep the raw artifact in a restricted directory if
needed for evidence; do not copy the secret elsewhere.

## Merge into swarmrecon

```text
17-js-api-cloud/
├── secrets-redacted.tsv
├── secrets-trufflehog.jsonl   # restricted; may contain raw matches
├── secrets-gitleaks.json      # restricted
└── manual-secrets.md
```

Ledger type: `secret`, with `evidence` pointing to the restricted artifact.
Edges: `contains_secret` from the hosting JS/URL/repo.

## Stop lines

- Do not validate, use, replay, or rotate a discovered secret.
- Do not authenticate with it.
- Do not access private repositories or private data.
- Do not publish, commit, or paste the secret into a chat.
- Do not run install scripts from an untrusted package.
- Do not publish a package to test dependency confusion.
- If a live secret is found, stop scanning that artifact and report it through
  the engagement's disclosure channel.

## Manual follow-up

- Is the secret live, or a placeholder/test key?
- What scope does it have?
- Is it in a public artifact that is indexed or mirrored?
- Was it deleted from the current branch but still reachable in history?
- Does the same secret appear in CI logs or build artifacts?
- Who owns rotation and disclosure?

## Source notes

- Truffle Security: secrets in cloud development environments, deleted/private
  GitHub data, PNG metadata, Google API keys/Gemini.
- P4WNED for source-control exposure.
- Dependency confusion and CI worm research for supply-chain inventory.
- Web Hacking Techniques Index records 22–27, 40, 44–46.
