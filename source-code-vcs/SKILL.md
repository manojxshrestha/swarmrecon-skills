---
name: Source Code and VCS
description: Recon-only detection of exposed source-control metadata, backups, framework config, Perforce/CI services, and source-disclosure paths. Use when content discovery or port scanning suggests source or build artifacts are reachable.
---

# Source code and version control

## Unique attack surface

Source-control and build artifacts expose code, history, configuration, and
credentials:

- `.git`, `.svn`, `.hg`, `.bzr`, CVS metadata;
- Perforce (`p4`) servers and depots;
- TeamCity, Jenkins, GitLab, and CI artifact paths;
- ASP.NET `web.config`, `trace.axd`, `elmah.axd`, `bin/`, `App_Data/`;
- Java `WEB-INF/web.xml`, `META-INF/MANIFEST.MF`, `classes/`;
- PHP `composer.json`, `.env`, backups, logs;
- source maps and build manifests (see JS skill);
- public repository history and fork networks.

The unique risk is **reconstructing source or configuration without
authorization**. Detection should stop at the evidence; dumping is a separate,
authorized manual step.

## Signals worth chasing

- `/.git/HEAD` returns `200` and starts with `ref:`.
- `/.git/config` contains a remote URL, branch, or credentials.
- `/.svn/entries`, `/.hg/requires`, `/.bzr/branch/branch.conf`, `CVS/Root`.
- Directory listing on `.git/`, `backup/`, `src/`, `dist/`, `build/`.
- `WEB-INF/web.xml`, `META-INF/MANIFEST.MF`, `appsettings.json`,
  `web.config`, `trace.axd`, `elmah.axd`.
- Ports `1666` (Perforce), `1600`, `8080`, `8443`, `50000` (Jenkins),
  `8111` (TeamCity).
- Jenkins/TeamCity login pages, `/app/rest/server`, `/api/json`.
- Backup/archive files with source-like names.

## Safe collection

### 1. Path checks

```bash
for p in .git/HEAD .git/config .svn/entries .hg/requires \
         .bzr/branch/branch.conf CVS/Root \
         WEB-INF/web.xml META-INF/MANIFEST.MF \
         appsettings.json web.config trace.axd elmah.axd; do
  curl -sS -o "source/$(echo "$p" | tr '/' '_')" \
    -w '%{http_code} %{content_type} %{size_download} %{url_effective}\n' \
    "https://app.example.com/$p"
done
```

Use GET/HEAD only. Keep a small response excerpt, not the whole repository.

### 2. Git metadata triage

If `.git/HEAD` is readable:

- read `HEAD`, `config`, and `packed-refs`;
- record the remote URL and branch;
- do **not** dump objects or reconstruct the repository;
- compare the remote with the target's public repos.

### 3. Perforce / CI fingerprint

```bash
nmap -Pn -sV -p 1666,1600,8080,8443,50000,8111 <ip>
curl -sS -I --max-time 10 https://ci.example.com/
```

For Perforce, record the banner/version and whether authentication is
required. Do not attempt default accounts, ticket auth, or depot sync.

### 4. ASP.NET / Java / PHP config

Record status, content type, and a short excerpt. Do not download databases or
full config files. If a config file contains credentials, switch to the
secret-exposure skill and redact.

### 5. Public repository history

- Scan only public repos.
- Use shallow clones and a size cap.
- Record deleted/forked data only as a lead; do not attempt to recover private
  objects.
- Do not publish or redistribute source.

## Merge into swarmrecon

```text
20-source-vcs/
├── exposure.tsv      # url, type, status, content_type, evidence, confidence
├── vcs-remotes.tsv   # host, vcs, remote, branch, source
├── perforce.tsv      # ip, port, banner, auth_required
├── ci.tsv            # url, product, version, auth_required
└── manual-source.md
```

Ledger types: `url`, `service`, `repo`. Edges: `exposes`, `same_host`,
`references`.

## Stop lines

- Do not dump a repository, database, or full config file.
- Do not authenticate, try default credentials, or sync a Perforce depot.
- Do not exploit CI/CD, build agents, or plugins.
- Do not access private repositories or deleted objects.
- Do not publish or redistribute source.
- Stop at the minimum evidence needed to prove exposure.

## Manual follow-up

- Is the repository intentionally public?
- Does the exposed metadata include a remote URL, branch, or credential?
- Is the source current, or a stale backup?
- Does the config expose database/API credentials?
- Is Perforce/CI reachable from the internet by design?
- What is the disclosure and remediation path?

## Source notes

- P4WNED, *How Insecure Defaults in Perforce Expose Source Code Across the
  Internet*.
- PT Security, *Source Code Disclosure in ASP.NET apps*.
- TeamCity source-risk and GitHub Actions worm research (inventory only).
- Web Hacking Techniques Index records 23–25, 44–45.
