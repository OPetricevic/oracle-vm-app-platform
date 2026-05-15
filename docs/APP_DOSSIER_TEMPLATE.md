# App Dossier Template

Use one dossier per app. Keep it focused on what helps deploy, maintain, or debug the app.

```markdown
# <app-slug>

## Purpose

What the app does in one or two lines.

## Runtime

- language/framework:
- container or process model:
- production runtime port:
- development runtime port:

## Database

- engine:
- production database name:
- development database name:
- production user:
- development user:
- migration entrypoint:

## Storage

- uploads path:
- object storage, if any:

## Domains

- production frontend:
- production API:
- development frontend:
- development API:

## Deploy Path

- CI workflow:
- server script:
- rollback path:

## Secrets / Env

- required secrets:
- required env vars:

## Known Risks

- data that can grow quickly:
- external dependencies:
- anything brittle:

## Last Verified

- date:
- what was checked:
```
