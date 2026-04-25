# Local secrets

Files in this directory are injected into Compose services via the top-level
`secrets:` block (docker-compose rule 13). They are never baked into images.

- `postgres_password` — plaintext password for the local Postgres container.

Both files are gitignored. Generate them locally:

```bash
openssl rand -base64 32 > secrets/postgres_password
chmod 600 secrets/postgres_password
```
