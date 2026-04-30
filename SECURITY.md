# Security Policy

This repository is an infrastructure template. It should never contain live server secrets or private user data.

## Never Commit

- real `.env` files
- SSH private keys
- API tokens
- Oracle Cloud identifiers
- Cloudflare tokens
- database dumps
- backup archives
- uploaded user files
- screenshots containing IPs, domains, emails, dashboards, or account details

## Reporting Issues

If you find a security problem in the template, open a GitHub issue with enough detail to reproduce the problem.

If the problem involves exposed credentials from your own deployment, rotate those credentials first, then investigate.

## Production Notes

- Keep Oracle security lists and UFW limited to SSH, HTTP, and HTTPS.
- Put admin tools behind SSH, Tailscale, Cloudflare Access, or strong app-level authentication.
- Test backup restoration before trusting the server with important data.
- Keep per-app secrets in `/etc/apps/<app>/<app>.env`, not in Git.
