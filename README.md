# traefik
IQB application infrastructure with Edge router, Identity Provider, and Monitoring

## CI checks
Pull requests against `develop` run these checks:
- `yamllint`
- `shellcheck` for scripts in `scripts/**/*.sh`
- `docker compose ... config -q` validation for development and production compose setups
