---
name: Identity and OAuth
description: Recon-only inventory of OAuth/OIDC, SAML, SSO, login portals, client IDs, redirect URIs, scopes, JWKS, and tenant hints. Use when the target has login/SSO or JavaScript references an identity provider.
---

# Identity and OAuth

## Unique attack surface

Identity flows expose a separate trust boundary:

- OAuth/OIDC authorization, token, JWKS, and discovery endpoints;
- client IDs, redirect URIs, response types, scopes, and grant types;
- SAML metadata, SSO redirects, and tenant discovery;
- login, registration, password-reset, MFA, and consent screens;
- API keys and tokens issued to first-party and third-party clients;
- error-response differences that reveal whether a client/tenant exists;
- post-login redirect behavior and open-redirect surfaces.

The unique risk is **trust misconfiguration**: a client/redirect/scope may be
accepted by an identity provider in a way the application does not expect. This
skill only inventories the surface. It does not automate client-ID spoofing,
password grants, token replay, or credential attacks.

## Signals worth chasing

- `/.well-known/openid-configuration`
- `/.well-known/oauth-authorization-server`
- `/.well-known/jwks.json`
- `/oauth/authorize`, `/oauth/token`, `/oauth2/`, `/authorize`, `/token`
- `client_id`, `redirect_uri`, `response_type`, `scope`, `state`, `nonce`
- `saml`, `SAMLRequest`, `SAMLResponse`, `adfs`, `okta`, `auth0`, `cognito`,
  `keycloak`, `entra`, `login.microsoftonline.com`
- `firebase auth`, `identitytoolkit.googleapis.com`
- `jwks_uri`, `issuer`, `authorization_endpoint`, `token_endpoint`
- JavaScript references to auth SDKs and tenant IDs.

## Safe collection

### 1. Fetch discovery documents

```bash
for p in .well-known/openid-configuration \
         .well-known/oauth-authorization-server \
         .well-known/jwks.json; do
  curl -sS -o "identity/$(echo "$p" | tr '/' '_')" \
    -w '%{http_code} %{content_type} %{url_effective}\n' \
    "https://app.example.com/$p"
done
```

Record issuer, endpoints, supported grant types, scopes, claims, and JWKS
metadata.

### 2. Extract client configuration from JS

Look for:

- `clientId`, `client_id`, `authority`, `issuer`, `redirectUri`;
- Auth0 domain, Okta domain, Cognito pool/client IDs;
- Entra tenant ID, Firebase project;
- requested scopes and response types.

Do not use a client ID to start a login flow without explicit approval.

### 3. Map login and SSO

- Identify login/registration/password-reset/MFA endpoints.
- Follow only normal GET redirects; record the chain and the identity provider.
- Record whether the app uses SAML, OIDC, or a custom session.
- Note tenant/domain hints in the login page and discovery docs.

### 4. Inventory redirect and scope behavior

From public configuration, record:

- registered redirect URIs (if exposed);
- allowed response types and grant types;
- scopes and whether `openid`, `offline_access`, or admin scopes appear;
- whether PKCE is advertised.

Do not test redirect manipulation, client spoofing, or token replay.

### 5. Error-response differences (manual note)

The OAuth client-ID spoofing research shows that some providers return
different errors for registered, unregistered, random, and malformed client
IDs. This can enumerate app registrations. Treat it as a **manual technique**
and do not build an automated enumeration loop.

## Merge into swarmrecon

```text
18-identity/
├── endpoints.tsv     # type, url, issuer, source
├── clients.tsv       # client_id, provider, redirect hints, scopes, source
├── jwks.json
├── sso-map.md
└── manual-identity.md
```

Ledger types: `api`, `url`, `host`. Edges: `references`, `same_host`,
`auth_provider`.

## Stop lines

- No client-ID spoofing automation, enumeration loop, or password grant.
- No credential stuffing, password spraying, or token replay.
- No auth bypass or session manipulation.
- No redirect-URI manipulation testing.
- No use of discovered client secrets/tokens.
- No login attempts without explicit authorization.

## Manual follow-up

- Which clients are public vs confidential?
- Are redirect URIs strictly registered?
- Are scopes least-privilege?
- Is PKCE required for public clients?
- Are tenant/domain hints exposed?
- Does the login page leak valid users/tenants through errors?
- Are deprecated grant types enabled?

## Source notes

- *OAuth Client ID Spoofing: Why Fake Client IDs Are Gaining Traction for
  Stealthy Enumeration* (inventory boundary only).
- Web Hacking Techniques Index record 32.
