# 07 - Public Routing and Cloudflare

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Expose public app routes through Caddy and, when useful, put Cloudflare in front of them.

## Host-Side Caddy

The host bootstrap makes Caddy import snippets from:

```text
/etc/caddy/apps/*.caddy
```

`provision-app.sh` can create a snippet automatically:

```bash
sudo APP_SLUG=physio-tracker \
  ENVIRONMENT=production \
  APP_TYPE=api \
  PUBLIC_DOMAIN=api.example.com \
  PORT=3600 \
  DB_ENGINE=postgres \
  DB_PASS='<SET_A_REAL_PASSWORD>' \
  ./provision-app.sh
```

API shape:

```caddy
api.example.com {
    encode gzip zstd
    reverse_proxy 127.0.0.1:3600
}
```

Static origin shape, if you choose to host static files on the VM:

```caddy
docs.example.com {
    root * /opt/apps/docs-site/shared/static
    file_server
}
```

## Cloudflare Side

Recommended pattern for modern apps:

```text
Cloudflare Pages or Worker assets:
  app.example.com

Oracle VM:
  api.example.com
  PostgreSQL/MySQL
  uploaded files
```

Your frontend can either call `https://api.example.com/api/...` directly, or a Worker can proxy `/api/...` to the VM.

## Cloudflare variable

If using a Worker proxy, set:

- `API_ORIGIN`

Use a normal plaintext variable, not a secret. Example:

```text
API_ORIGIN=https://api.example.com
```

The important sequence is:

1. make sure direct VM HTTP works first
2. then make sure the Cloudflare worker can reach that origin

Do not debug Cloudflare before proving the VM's public path.

## Temporary lock-down

If you prove the path works but do not want the app publicly usable yet, change Caddy to return `403` and keep the rest of the system intact.

That is safer than leaving an unfinished auth model exposed just because traffic volume is low.
