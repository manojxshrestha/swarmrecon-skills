---
name: Mobile API
description: Recon-only static analysis of a local APK/IPA to recover hidden or legacy mobile API endpoints, parameters, headers, deep links, and redacted configuration. Use when the target has a mobile app and the web surface looks incomplete.
---

# Mobile API

## Unique attack surface

Mobile clients often talk to APIs that the web app does not use:

- hidden, legacy, or internal API hosts;
- newer/older API versions with different validation;
- mobile-only headers (`X-App-Version`, `X-Device`, `X-Platform`);
- hardcoded endpoints, keys, and SDK configuration;
- deep links and associated domains;
- feature flags and staged rollouts;
- client-side validation assumptions that differ from web;
- debug/staging endpoints left in release builds.

The unique risk is **web-to-mobile inconsistency**: the same business logic may
be enforced differently on the mobile API. This skill only extracts the
surface from a local app; it does not run the app or intercept traffic.

## Signals worth chasing

- URLs and hostnames in `classes.dex`, native libraries, assets, plists, and
  JS bundles (React Native/Flutter/Cordova).
- `/api/`, `/graphql`, `/trpc`, `/rpc`, `/rest/`, `/mobile/`, `/v1/`, `/v2/`.
- `Authorization`, `Bearer`, `api_key`, `X-API-Key`, `X-App-Version`,
  `X-Device-ID`, `X-Client`.
- Deep links (`scheme://`, universal links), `assetlinks.json`,
  `apple-app-site-association`.
- Firebase/Supabase/AWS/Google SDK configuration.
- Debug/staging hosts, `localhost`, private IPs, and test domains.
- Obfuscated strings that decode to URLs (Base64, XOR, protobuf).

## Safe collection

### 1. Accept a local file only

The module takes an APK/IPA path supplied by the user. It must not scrape app
stores or download apps automatically.

```bash
# Verify file type
file app.apk app.ipa
sha256sum app.apk app.ipa
```

Record the hash and the app version. Do not redistribute the app.

### 2. APK static extraction

```bash
apktool d -f app.apk -o mobile/apktool
jadx -d mobile/jadx app.apk
unzip -q app.apk -d mobile/unzipped

# Strings and URL-like patterns
strings -a app.apk > mobile/strings.txt
rg -o 'https?://[^"'\'' <>]+' mobile/ > mobile/urls.txt
rg -o '/[A-Za-z0-9._~-]+/[A-Za-z0-9._~/-]*' mobile/ > mobile/paths.txt
```

Review `AndroidManifest.xml` for exported components, deep links, network
security config, and permissions. Do not launch activities.

### 3. IPA static extraction

```bash
unzip -q app.ipa -d mobile/ipa
plutil -convert xml1 mobile/ipa/Payload/*.app/Info.plist -o mobile/info.plist
strings -a mobile/ipa/Payload/*.app/* > mobile/strings.txt
```

Review `Info.plist` for URL schemes, associated domains, ATS settings, and
embedded frameworks. Do not run the app.

### 4. React Native / Flutter / Cordova

- React Native: `index.android.bundle`, `main.jsbundle`, Hermes bytecode.
- Flutter: `libapp.so`, `flutter_assets/`.
- Cordova/Ionic: `assets/www/`.
- Extract URLs and API strings with `strings`/`rg`; use the JS skill for
  bundles that are plain JavaScript.

### 5. Normalize into the API graph

For each endpoint record:

```text
host  path  method_hint  headers  params  auth_hint  source_file  confidence
```

Merge with web/API inventory. A mobile-only host is a high-value lead because
it may not appear in CT or crawl data.

## Merge into swarmrecon

```text
19-mobile/
├── app-hash.txt
├── endpoints.tsv
├── hosts.txt
├── headers.tsv
├── deeplinks.tsv
├── secrets-redacted.tsv
└── manual-mobile.md
```

Ledger types: `mobile_endpoint`, `host`, `api`, `secret`.

## Stop lines

- Local file only; no app-store scraping or automatic download.
- No dynamic instrumentation, Frida, MITM, or certificate-pinning bypass.
- No login attempts, credential use, or token replay.
- No exploitation of exported components.
- No redistribution of the app or its proprietary code.
- Redact keys and tokens.

## Manual follow-up

- Is the mobile-only host reachable and in scope?
- Does it use a different auth/validation model from web?
- Are debug/staging endpoints present in the release build?
- Are deep links/universal links pointing at sensitive routes?
- Are exported components reachable without authentication?
- Are embedded keys expected (public SDK keys) or sensitive?

## Source notes

- WARDroid, *Mobile Application Web API Reconnaissance*.
- *Uncovering and Exploiting Hidden APIs in Mobile Super Apps* (discovery half
  only).
- Web Hacking Techniques Index records 5 and 6.
