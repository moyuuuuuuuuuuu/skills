---
name: apipost-openapi-docs
description: Manage ApiPost API documentation through ApiPost OpenAPI or exported OpenAPI definitions. Use when Codex needs to create, update, delete, list, inspect, or synchronize ApiPost API docs, folders, Markdown docs, interfaces, share links, or documentation metadata by calling ApiPost OpenAPI endpoints or by preparing requests from an ApiPost-provided OpenAPI/cURL definition.
---

# ApiPost OpenAPI Docs

Use this skill to manage ApiPost API documentation through a user-provided ApiPost OpenAPI definition, copied cURL, or official endpoint details. Do not invent ApiPost endpoint paths: the public site confirms OpenAPI support, but exact management endpoints may be tenant/version-specific or not publicly exposed.

## Repository code-derived documentation

Before synchronizing, read the target repository AGENTS.md and applicable API documentation rules. Their scope and existing-directory configuration protections take precedence over the general workflow below.

When asked to supplement request descriptions or Chinese response examples, trace the actual route, Request scene, Controller, Business branches, and Resource. Use CodeGraph first when the repository has an index. Derive nesting, collections, pagination, enum meanings, nullable fields, and conditional output from that code; do not invent missing fields. Keep the real contract in the schema and use Chinese field meanings as response example values according to the project rules.

For documentation-only requests, change only the relevant documentation and synchronization artifacts. Do not alter routes or implementation to make an example convenient. Verify the local OpenAPI parses, synchronize only the requested interfaces, and read back their details. Preserve existing directory authentication, public parameters, and scripts; do not reconfigure them to satisfy generic inheritance advice below. Report local completion and remote synchronization separately when remote access is blocked.

## Source inputs

Prefer these sources, in order:

1. A local OpenAPI 3.x JSON file from ApiPost or the user's tenant.
2. A copied cURL command from ApiPost's "external OpenAPI" window.
3. Official endpoint details supplied by the user.
4. Public docs only for general behavior and feature confirmation.

Use `references/apipost-openapi.md` when you need the current public notes, trigger terms, or operation discovery guidance.

## Environment

Use environment variables instead of embedding credentials in files:

- `APIPOST_OPENAPI_SPEC`: local OpenAPI JSON file path.
- `APIPOST_BASE_URL`: optional base URL override. Otherwise use the first `servers[].url` value in the spec.
- `APIPOST_TOKEN`: token or API key.
- `APIPOST_TOKEN_HEADER`: auth header name, defaults to `Api-Token` for ApiPost open endpoints.
- `APIPOST_TOKEN_PREFIX`: auth prefix, defaults to an empty string. Set explicitly only if the endpoint requires a prefix.
- `APIPOST_PROJECT_ID`, `APIPOST_TEAM_ID`: optional IDs to fill request templates when the spec uses those names.

Never print raw tokens. In final answers, mention only whether auth variables were present.

## Workflow

1. Identify the source of truth: OpenAPI JSON, cURL, or endpoint details.
2. Run an operation discovery pass before modifying data:

   ```powershell
   .\scripts\apipost_docs.ps1 -SpecPath $env:APIPOST_OPENAPI_SPEC -Action operations
   ```

3. Map the user intent to an operation:

   - Create docs: search operation IDs, summaries, tags, or paths for `create`, `add`, `new`, `save`, `doc`, `api`, `interface`, `markdown`.
   - Update docs: search for `update`, `edit`, `modify`, `save`, `doc`, `api`, `interface`, `markdown`.
   - Delete docs: search for `delete`, `remove`, `trash`, `doc`, `api`, `interface`, `markdown`.
   - List/get docs: search for `list`, `get`, `detail`, `search`, `tree`, `folder`, `project`.

4. Build a JSON body file for the operation. Keep IDs, folder placement, request method, path, headers, parameters, schemas, examples, and descriptions explicit.
5. Dry-run the request first. Review the URL, method, and payload:

   ```powershell
   .\scripts\apipost_docs.ps1 -SpecPath $env:APIPOST_OPENAPI_SPEC -Action request -OperationId createDoc -BodyPath .\payload.json
   ```

6. Execute only after the operation and payload are clearly correct:

   ```powershell
   .\scripts\apipost_docs.ps1 -SpecPath $env:APIPOST_OPENAPI_SPEC -Action request -OperationId createDoc -BodyPath .\payload.json -Execute
   ```

7. Verify by calling a get/list operation or by checking the returned document ID/version.

## Directory Rules and Sync Strategy

Follow the target project's existing directory tree, naming conventions, and authentication rules. Do not impose another project's folder names or authentication inheritance. Preserve existing authentication, public parameters, and scripts unless a change is explicitly authorized.

Prefer scoped create/update operations for the requested interfaces. Discover endpoint methods and payloads from the supplied OpenAPI definition or tenant documentation; do not assume an endpoint or HTTP method from another deployment.

Use the target project's existing importer for bulk synchronization only when appropriate to the requested scope. Inspect its effects first, especially directory and authentication changes. Verify writes with a details or list read-back and distinguish local document completion from remote synchronization.

## Safety

- Treat create, update, and delete as write operations. Use dry-run first.
- For delete, require a concrete document/interface/folder ID from the user or from a previous list/get response.
- For update, avoid replacing a whole document unless the API requires it. Prefer patch/update endpoints when available.
- Preserve user-authored fields. When the API requires full replacement, fetch the current document, merge intended changes, then update.
- If the OpenAPI definition lacks the needed operation, ask the user for the missing ApiPost cURL or endpoint documentation.

## Bundled Script

Use `scripts/apipost_docs.ps1` for JSON OpenAPI discovery and request execution. It supports:

- Listing operations from an OpenAPI JSON file.
- Resolving operations by `operationId`, or by method plus path.
- Replacing path parameters from JSON and environment IDs.
- Adding query parameters from JSON.
- Sending JSON request bodies.
- Dry-run by default, with `-Execute` required for network calls.

The script intentionally does not parse YAML. If the user provides YAML, convert/export it to JSON first or ask for the JSON export.

Use `scripts/apipost_open.ps1` for known ApiPost open endpoints when the user supplies `APIPOST_HOST`, `APIPOST_TOKEN`, and `APIPOST_PROJECT_ID`:

```powershell
.\scripts\apipost_open.ps1 -Action list
.\scripts\apipost_open.ps1 -Action detail -TargetIds target_id_here
```

Both commands dry-run by default. Add `-Execute` only after confirming the URL, payload, and target IDs.

## Encoding

Always read ApiPost-exported JSON as UTF-8. Windows PowerShell may default to the local ANSI code page and show Chinese text as mojibake when `Get-Content` omits `-Encoding UTF8`.
