# Security Notes

## Published host ports bypass the firewall

The installer configures `ufw` with `default deny incoming`, but **that does not cover Docker.** Docker publishes container ports in the `nat` table, which is evaluated *before* the `INPUT` chain `ufw` uses — so any port a container publishes on `0.0.0.0` is reachable from the internet regardless of your firewall rules. See [Docker: packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/).

By design this stack publishes almost nothing: every service is reached through Caddy on ports 80/443 only. To audit what is actually exposed on your server:

```bash
docker ps --format '{{.Names}}\t{{.Ports}}'   # the reliable check
ss -ltnp                                      # host listeners
```

Trust `docker ps` here: with `"userland-proxy": false` the listener is owned by `dockerd` rather than a `docker-proxy` process, so `ss` output is easy to misread even though the port is published.

Anything showing `0.0.0.0:<port>->` is internet-reachable if your server has a public IP.

- **Neo4j Bolt (`7687`)** — Caddy publishes `0.0.0.0:7687` (TLS, proxied to Neo4j for Neo4j Browser) only while the `neo4j` profile is active, via `docker-compose.neo4j.yml`. Before 1.16.2 it was published on every install; the next `make update` or `make restart` closes it when Neo4j is not selected.
- **Supabase API gateway** — bound to `127.0.0.1:8000` by default. Caddy still reaches it over the Docker network, and host-local tooling (`curl http://localhost:8000`) keeps working. To expose it deliberately, set `API_GW_HTTP_PORT` in `.env` (e.g. `API_GW_HTTP_PORT=8000` for all interfaces, or `API_GW_HTTP_PORT=192.168.1.10:8000` for one LAN address) and run `make restart`. `make doctor` warns if the gateway is bound to all interfaces.
- **Supabase database and pooler** — Supabase's upstream compose still publishes `0.0.0.0:5432` and `0.0.0.0:6543` from its `supavisor` service (container `supabase-pooler`). **If you run the `supabase` profile on a public-IP server, restrict these at your cloud provider's firewall or security group**, which is enforced outside the host and therefore not bypassed by Docker. You can close the pooler port yourself by setting `POOLER_PROXY_PORT_TRANSACTION=127.0.0.1:6543` in **`supabase/docker/.env`** — that is the file Compose interpolates for the Supabase stack, and the variable is only used for the port mapping. Editing the root `.env` has no effect here: the installer copies it to `supabase/docker/.env` once and afterwards only appends keys that are *missing* there, and only `API_GW_HTTP_PORT`/`KONG_HTTP_PORT`/`KONG_HTTPS_PORT` are force-synced. Re-apply your edit after any upstream change that recreates that file. The `5432` mapping cannot be handled the same way: `POSTGRES_PORT` is reused as a bare numeric port throughout Supabase's own connection strings, so it cannot take an address prefix.
