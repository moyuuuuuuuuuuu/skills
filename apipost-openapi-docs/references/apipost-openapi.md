# ApiPost OpenAPI Reference Notes

Checked against public ApiPost pages on 2026-05-20.

## Publicly confirmed capabilities

- ApiPost Open Platform says it supports reading and modifying data under an ApiPost account through open APIs: https://open.apipost.cn/
- The same page lists "interfaces/docs related" documentation areas, but the public "enter open platform" page currently displays an internal-beta notice.
- ApiPost changelog says v8.0.8 added outward-facing OpenAPI support, and v8.1.14 added sharing documents in OpenAPI 3.0 format: https://wiki.apipost.cn/docs/changelog
- ApiPost "external OpenAPI" docs explain that a selected interface, case, or automated test case can expose a callable OpenAPI/cURL request: https://wiki.apipost.cn/docs/call-openapi
- ApiPost product docs describe API docs as generated from the same data source as API design/debugging and shareable as online HTML, Markdown, Word, and OpenAPI formats: https://wiki.apipost.cn/docs/introduction

## Practical implication

Do not hardcode management endpoint paths from memory. Ask the user for one of:

- The tenant-specific ApiPost OpenAPI JSON.
- A copied cURL command from the relevant ApiPost OpenAPI window.
- Official endpoint documentation for the user's ApiPost version or private deployment.

Known public/community references for ApiPost open endpoints indicate:

- Host default: `https://open.apipost.net`
- Auth header: `Api-Token: <token>`
- List APIs: `POST /open/apis/list` with `project_id`
- Detail APIs: `POST /open/apis/details` with `project_id` and `target_ids`
- Create APIs/folders: `POST /open/apis/create`

Treat create/update/delete schemas as version-sensitive. Prefer a dry-run payload and, when possible, inspect an existing object through `/open/apis/details` before writing.

## Operation discovery terms

Use these terms when scanning operation IDs, tags, summaries, and paths:

- Documentation objects: `doc`, `docs`, `document`, `markdown`, `api`, `interface`, `folder`, `directory`, `share`, `archive`.
- Create: `create`, `add`, `new`, `save`, `import`.
- Update: `update`, `edit`, `modify`, `patch`, `move`, `rename`, `status`.
- Delete: `delete`, `remove`, `trash`, `recycle`.
- Read: `list`, `get`, `detail`, `tree`, `search`, `export`.

## Common payload fields to preserve

When building or merging request bodies, keep these fields if present in the existing object or the OpenAPI schema:

- Identity and placement: `id`, `api_id`, `doc_id`, `target_id`, `project_id`, `team_id`, `parent_id`, `folder_id`.
- Interface basics: `name`, `title`, `method`, `url`, `path`, `description`, `status`, `tags`.
- Request data: `headers`, `query`, `path_params`, `request_body`, `body`, `content_type`.
- Response docs: `responses`, `response_examples`, `response_schema`, `status_codes`.
- Documentation text: `markdown`, `content`, `remark`, `schema`, `examples`.
- Collaboration metadata: `version`, `updated_at`, `lock`, `archive`, `share_id`.

## Recommended CRUD flow

Create:

1. Discover create/save/import operations.
2. Build a body with project/folder IDs and complete interface documentation.
3. Dry-run.
4. Execute.
5. Verify through get/list/tree.

Update:

1. Fetch the existing object.
2. Merge only intended changes.
3. Dry-run the update.
4. Execute.
5. Verify changed fields and returned version.

Delete:

1. Resolve an exact document/interface/folder ID.
2. Prefer recycle/trash endpoints if the spec exposes them.
3. Dry-run the delete.
4. Execute only with explicit user intent.
5. Verify the item is absent or moved to recycle bin.
