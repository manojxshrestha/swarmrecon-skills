---
name: API Surface
description: Recon-only inventory of GraphQL, tRPC, OpenAPI/Swagger, REST, gRPC-Web, and WebSocket surfaces. Use when JavaScript, crawl data, or paths suggest an API that is richer than the HTML site.
---

# API surface

## Unique attack surface

APIs expose operations, parameters, object references, and authorization
boundaries that the HTML UI never shows. The recon-relevant surface includes:

- GraphQL endpoints, schemas, hidden fields, batching, and GraphiQL;
- tRPC routers/procedures, batched calls, and `superjson` payloads;
- OpenAPI/Swagger specs that describe paths, parameters, objects, and security
  schemes;
- REST path/query/body parameters and versioned routes;
- gRPC-Web services and methods, including services named in JS;
- WebSocket and Server-Sent Events endpoints;
- object identifiers (numeric, UUID, slug, hash) that indicate BOLA/IDOR
  candidates;
- auth hints: bearer tokens, API keys, cookies, CSRF headers, tenant IDs.

The goal is to **map the API**, not to fuzz it or exploit authorization flaws.

## Signals worth chasing

- `/graphql`, `/graphiql`, `/api/graphql`, `/v1/graphql`, `/query`.
- `/trpc/`, `?batch=1`, `superjson`, `trpc` strings in bundles.
- `/openapi.json`, `/openapi.yaml`, `/swagger.json`, `/swagger.yaml`,
  `/v3/api-docs`, `/swagger-resources`, `/api-docs`.
- `/api/v1/`, `/rest/`, `/rpc/`, `/services/`, `/json/`, `/actions/`,
  `/batch/`, `/webhook/`.
- `application/grpc-web`, `application/grpc-web+proto`, `grpc-status`.
- `wss://`, `socket.io`, `/events`, `/stream`, `/sse`.
- Path segments that are numeric IDs, UUIDs, long hex strings, or slugs.
- Query parameters such as `id`, `user_id`, `account_id`, `tenant`,
  `organization_id`, `project_id`, `role`, `admin`.
- JS strings like `operationName`, `query`, `mutation`, `subscription`,
  `procedure`, `router`, `input`, `variables`.

## Safe collection

### 1. Discover endpoints from crawl/JS

Use the crawl and JS skills first. Then normalize:

```bash
# From a URL corpus, keep API-looking routes
./filter.sh   # existing classifier; writes check/api-candidates.txt

# From JS strings (example; use jsluice or a reviewed extractor)
rg -o 'https?://[^"'\'' ]+|/(api|graphql|trpc|rpc|rest)/[^"'\'' ]+' js/ \
  | sort -u > api/candidates.txt
```

Do not execute bundle code. Parse strings and source maps.

### 2. GraphQL

Read-only checks:

```bash
curl -sS -D - -o /dev/null https://app.example.com/graphql
curl -sS -H 'Content-Type: application/json' \
  --data '{"query":"{__typename}"}' \
  https://app.example.com/graphql
```

The `__typename` query is a minimal liveness check. Full introspection is
**opt-in** (`--graphql-introspect`) because schemas can disclose sensitive
fields. If enabled, store the schema and stop; do not send mutations.

Record:

- endpoint, status, content type;
- whether introspection is enabled;
- GraphiQL/Playground presence;
- batching support;
- auth/CSRF behavior;
- error-message style.

### 3. tRPC

Look for:

- `/trpc/<router>.<procedure>`;
- `?batch=1&input=...`;
- client strings such as `createTRPCClient`, `httpBatchLink`, `superjson`;
- router/procedure names in source maps.

Do not call mutations. A read-only query is acceptable only if it is
non-destructive and explicitly in scope.

### 4. OpenAPI / Swagger

Probe common spec locations, then parse:

```bash
for p in openapi.json openapi.yaml swagger.json swagger.yaml \
         v3/api-docs api-docs swagger-resources; do
  curl -sS -o "specs/$(echo "$p" | tr '/' '_')" \
    -w '%{http_code} %{content_type} %{url_effective}\n' \
    "https://app.example.com/$p"
done
```

For each valid spec, extract:

- `servers`, `paths`, methods, parameters (path/query/header/cookie);
- request/response schemas and object IDs;
- security schemes and scopes;
- deprecated/hidden operations;
- examples containing hostnames or tokens.

Do not send the described requests; this is a schema inventory.

### 5. REST and object references

From crawl/JS, extract:

- path templates (`/api/v1/users/{id}`);
- query/body parameter names;
- IDs and UUIDs;
- tenant/account/org fields;
- version prefixes.

Feed `filter.sh`'s `idor-candidates.txt` and `api-candidates.txt` into the
ledger. Mark object references as **candidates**, not vulnerabilities.

### 6. gRPC-Web

Detect:

- `content-type: application/grpc-web`;
- `grpc-status` / `grpc-message` headers;
- service/method strings in JS;
- `.proto` files or generated clients in source maps.

`grpcurl` reflection is opt-in and only against in-scope endpoints. Do not send
mutations or brute-force methods.

### 7. WebSocket / SSE

Record the URL, subprotocol, origin behavior, and auth mechanism. Do not send
application messages unless a human explicitly approves a read-only handshake.

## Merge into swarmrecon

```text
17-js-api-cloud/
├── endpoints.tsv     # endpoint, method, source, auth_hint, schema_ref
├── params.tsv        # endpoint, location, name, type, object_ref
├── schemas/          # OpenAPI/GraphQL SDL/tRPC inventory
├── ws.tsv
└── manual-api.md
```

Ledger types: `api`, `url`, `js`. Edges: `references`, `calls`, `same_host`.

## Stop lines

- No mutations, writes, deletes, or state changes.
- No auth brute force, password grant, token replay, or credential stuffing.
- No BOLA/IDOR exploitation; only candidate inventory.
- No introspection by default; opt-in and logged.
- No gRPC reflection against third parties.
- No fuzzing of request bodies or parameters in this skill.
- No use of keys/tokens found in JS.

## Manual follow-up

- Which endpoints require auth, and which return data without it?
- Are object IDs sequential or guessable?
- Are tenant/org IDs accepted from the client?
- Does the schema expose admin/internal operations?
- Is introspection enabled in production?
- Are deprecated API versions still live?
- Does GraphQL batching bypass rate limits or auth checks?

## Source notes

- Doyensec, *GraphQL Security Overview and Testing Tips*.
- Doyensec, *That single GraphQL issue that you keep missing*.
- tRPC security research.
- *A Deep Dive into OpenAPI Security*.
- *Vulnerability-oriented Testing for RESTful APIs* (VOAPI2).
- *Hacking into gRPC-Web*.
- Web Hacking Techniques Index records 7–11 and 36.
