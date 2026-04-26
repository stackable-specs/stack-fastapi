# Local secrets

Files in this directory are injected into Compose services via the top-level
`secrets:` block (docker-compose rule 13). They are never baked into images.

- `postgres_password` — plaintext password for the local Postgres container.
- `openobserve_token` — full `OTEL_EXPORTER_OTLP_HEADERS` value (e.g.
  `Authorization=Basic <base64(email:password)>`) the api uses to authenticate
  OTLP ingest. The api reads this file at startup and exports the variable
  before the OTel SDK initializes, so no credential lives in `compose.yaml`.

All files are gitignored. Generate them locally:

```bash
openssl rand -base64 32 > secrets/postgres_password
chmod 600 secrets/postgres_password

# OpenObserve auth header (default user is root@example.com / changeme):
printf 'Authorization=Basic %s\n' \
  "$(printf 'root@example.com:changeme' | base64)" \
  > secrets/openobserve_token
chmod 600 secrets/openobserve_token
```
