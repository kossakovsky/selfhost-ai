# Caddy Addons

This directory allows you to extend or override Caddy configuration without modifying the main `Caddyfile`.

Files matching `site-*.conf` in this directory are automatically imported via `import /etc/caddy/addons/site-*.conf` in the main Caddyfile.

## Use Cases

- Custom TLS certificates (corporate/internal CA)
- Additional reverse proxy rules
- Custom headers or middleware
- Rate limiting or access control

## Custom TLS Certificates

For corporate/internal deployments where Let's Encrypt is not available, you can use your own certificates.

### How It Works

The main `Caddyfile` imports a TLS snippet that all service blocks use:

```caddy
# In Caddyfile (top)
import /etc/caddy/addons/tls-snippet.conf

# In each service block
{$N8N_HOSTNAME} {
    import service_tls    # <-- Uses the snippet
    reverse_proxy n8n:5678
}
```

By default, the snippet is empty (Let's Encrypt is used). When you run `make setup-tls`, the snippet is updated with your certificate paths.

### Quick Setup

1. Place your certificates in the `certs/` directory:
   ```bash
   cp /path/to/your/cert.crt ./certs/wildcard.crt
   cp /path/to/your/key.key ./certs/wildcard.key
   ```

2. Run the setup script:
   ```bash
   make setup-tls
   ```

3. The script will:
   - Update `caddy-addon/tls-snippet.conf` with your certificate paths
   - Optionally restart Caddy to apply changes

### Reset to Let's Encrypt

To switch back to automatic Let's Encrypt certificates:

```bash
make setup-tls --remove
```

Or run directly:
```bash
bash scripts/setup_custom_tls.sh --remove
```

## File Structure

```
caddy-addon/
├── .gitkeep                    # Keeps directory in git
├── README.md                   # This file
├── tls-snippet.conf.example    # Template for TLS snippet (tracked in git)
├── tls-snippet.conf            # Your TLS config (gitignored, auto-created)
└── site-*.conf                 # Your custom addons (gitignored, must start with "site-")

certs/
├── .gitkeep                    # Keeps directory in git
├── wildcard.crt                # Your certificate (gitignored)
└── wildcard.key                # Your private key (gitignored)
```

## Adding Custom Addons

You can create `site-*.conf` files for custom Caddy configurations. They will be automatically loaded by the main Caddyfile.

**Important:** Custom addon files MUST start with `site-` prefix to be loaded (e.g., `site-custom.conf`, `site-myapp.conf`).

Example: `caddy-addon/site-custom-headers.conf`
```caddy
# Add custom headers to all responses
(custom_headers) {
    header X-Custom-Header "My Value"
}
```

Example: expose a service that runs outside this stack (e.g. on the host or another machine). Because these files are gitignored, the entry survives `make update` — no need to re-add it after upgrades.

`caddy-addon/site-myapp.conf`
```caddy
myapp.yourdomain.com {
    import service_tls
    # host.docker.internal reaches the host machine from inside the Caddy container
    reverse_proxy host.docker.internal:3000
}
```

For a service on the host machine, two more things are needed. First, find the subnet and gateway of this stack's Docker network:

```bash
docker network inspect localai_default --format '{{range .IPAM.Config}}{{.Subnet}} (gateway {{.Gateway}}){{end}}'
```

1. The service must listen on an address the Caddy container can reach — not only `127.0.0.1`. Prefer the gateway IP from the command above over `0.0.0.0`, which would expose the service on every host interface and bypass Caddy if the firewall ever changes.
2. The installer's firewall (UFW) blocks container-to-host traffic by default. Allow the port for the subnet from the command above, e.g.:
   ```bash
   sudo ufw allow from 172.18.0.0/16 to any port 3000
   ```

## Important Notes

- `tls-snippet.conf.example` is tracked in git (template with default Let's Encrypt behavior)
- `tls-snippet.conf` is gitignored and auto-created from template (preserved during updates)
- `site-*.conf` files are gitignored (preserved during updates)
- Files in `certs/` are gitignored (certificates are not committed)
- Caddy validates configuration on startup - check logs if it fails:
  ```bash
  docker compose -p localai logs caddy
  ```

## Caddy Documentation

- [Caddyfile Syntax](https://caddyserver.com/docs/caddyfile)
- [TLS Directive](https://caddyserver.com/docs/caddyfile/directives/tls)
- [Reverse Proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
