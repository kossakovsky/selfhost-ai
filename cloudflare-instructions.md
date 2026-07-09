# 🔒 Secure Access with Cloudflare Tunnel (Optional)

Cloudflare Tunnel provides zero-trust access to your services without exposing any ports on your server. All traffic is routed through Cloudflare's secure network, providing DDoS protection and hiding your server's IP address.

### ⚠️ Important Architecture Note

Cloudflare Tunnel **bypasses Caddy** and connects directly to your services. This means:
- You get Cloudflare's security features (DDoS protection, Web Application Firewall, etc.)
- You lose Caddy's authentication features (basic auth for Prometheus, ComfyUI, SearXNG, etc.)
- Each service needs its own public hostname configuration in Cloudflare

### Benefits
- **No exposed ports** - Ports 80/443 can be completely closed on your firewall
- **DDoS protection** - Built-in Cloudflare protection
- **IP hiding** - Your server's real IP is never exposed
- **Zero-trust security** - Optional Cloudflare Access integration
- **No public IP required** - Works on private networks

### Setup Instructions

#### 1. Create a Cloudflare Tunnel

1. Go to [Cloudflare One Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** → **Connectors** → **Cloudflare Tunnels**
3. Click **Create a tunnel**
4. Select **Cloudflared** as the connector type and click **Next**
5. Name your tunnel (e.g., "n8n-install") and click **Save tunnel**
6. Copy the installation command shown - it contains your tunnel token

#### 2. DNS Configuration (Critical!)

⚠️ **Important**: For Cloudflare Tunnel to work, your domain's DNS **must be managed by Cloudflare**. When DNS is managed by Cloudflare:
- Public hostnames automatically create CNAME records pointing to the tunnel
- Records appear with **Proxy status ON** (orange cloud)
- Traffic routes through Cloudflare's network

##### Option A: Transfer DNS to Cloudflare (Recommended)

If your domain DNS is managed elsewhere (DigitalOcean, GoDaddy, Namecheap, etc.), you need to transfer it to Cloudflare:

1. **Add domain to Cloudflare**:
   - Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
   - Click **Add a site** → enter your domain (e.g., `yourdomain.com`)
   - Select the **Free** plan (or higher)
   - Cloudflare will scan existing DNS records

2. **Review DNS records**:
   - Cloudflare imports your existing records automatically
   - Verify all records are present (especially A records for your server)
   - **Delete** any A records for subdomains you want to route through the tunnel

3. **Update nameservers at your registrar**:
   - Cloudflare shows two nameservers (e.g., `anna.ns.cloudflare.com`, `bob.ns.cloudflare.com`)
   - Go to your domain registrar (DigitalOcean, GoDaddy, Namecheap, etc.)
   - Change nameservers from current to Cloudflare's nameservers
   - **DigitalOcean example**: Networking → Domains → your domain → change NS records

4. **Wait for propagation**:
   - DNS propagation takes 5 minutes to 48 hours (usually under 1 hour)
   - Most users see propagation complete within 10-30 minutes
   - Check status: `dig NS yourdomain.com` — should show Cloudflare nameservers
   - Cloudflare dashboard will show "Active" when complete

##### Option B: External DNS with Manual CNAME (Not Recommended)

> **Warning**: This approach is for advanced users only. You lose most Cloudflare benefits and must maintain DNS records manually. Strongly consider Option A instead.

If you cannot transfer DNS to Cloudflare, you can manually create CNAME records pointing to the tunnel. **Note**: This provides limited functionality — no automatic DNS management, no orange cloud proxy benefits.

1. **Get your tunnel ID**:
   ```bash
   # From tunnel logs
   docker compose -p localai logs cloudflared 2>&1 | grep "Connector ID"
   ```
   Or find it in Cloudflare Zero Trust → Tunnels → your tunnel → Overview

2. **Create CNAME in your DNS provider** (e.g., DigitalOcean):
   ```
   Type:    CNAME
   Name:    databasus (or your subdomain)
   Value:   <tunnel-id>.cfargotunnel.com
   TTL:     Auto or 300
   ```

3. **Limitations of this approach**:
   - No Cloudflare proxy benefits (DDoS protection limited)
   - No automatic DNS record management
   - Must manually update if tunnel ID changes
   - Some Cloudflare features won't work

##### Verifying DNS Configuration

After setup, verify DNS points to Cloudflare:

```bash
# Check if domain resolves to Cloudflare IPs
dig +short yourdomain.com

# Cloudflare IPs are in ranges: 104.x.x.x, 172.x.x.x, etc.
# Your server IP means DNS is NOT going through Cloudflare

# Check nameservers
dig NS yourdomain.com +short
# Should show: xxx.ns.cloudflare.com
```

#### 3. Configure Public Hostnames

After DNS is configured, go to **Cloudflare One Dashboard** → **Networks** → **Connectors** → **Cloudflare Tunnels** → your tunnel → **Public Hostname** tab. For each service you want to expose, click **Add a public hostname** and configure:

| Service            | Public Hostname               | Service URL                  | Auth Notes          |
| ------------------ | ----------------------------- | ---------------------------- | ------------------- |
| **n8n**            | n8n.yourdomain.com            | `http://n8n:5678`            | Built-in login      |
| **ComfyUI**        | comfyui.yourdomain.com        | `http://comfyui:8188`        | ⚠️ Loses Caddy auth  |
| **Databasus**      | databasus.yourdomain.com      | `http://databasus:4005`      | Built-in login      |
| **Dify** ¹         | dify.yourdomain.com           | `http://nginx:80`            | Built-in login      |
| **Docling**        | docling.yourdomain.com        | `http://docling:5001`        | ⚠️ Loses Caddy auth  |
| **Flowise**        | flowise.yourdomain.com        | `http://flowise:3001`        | Built-in login      |
| **Grafana**        | grafana.yourdomain.com        | `http://grafana:3000`        | Built-in login      |
| **InvokeAI**       | invokeai.yourdomain.com       | `http://invokeai:9090`       | ⚠️ Loses Caddy auth  |
| **Langfuse**       | langfuse.yourdomain.com       | `http://langfuse-web:3000`   | Built-in login      |
| **Letta**          | letta.yourdomain.com          | `http://letta:8283`          | No auth             |
| **LibreTranslate** | libretranslate.yourdomain.com | `http://libretranslate:5000` | ⚠️ Loses Caddy auth  |
| **LightRAG**       | lightrag.yourdomain.com       | `http://lightrag:9621`       | No auth             |
| **Neo4j**          | neo4j.yourdomain.com          | `http://neo4j:7474`          | Built-in login      |
| **NocoDB**         | nocodb.yourdomain.com         | `http://nocodb:8080`         | Built-in login      |
| **Open WebUI**     | webui.yourdomain.com          | `http://open-webui:8080`     | Built-in login      |
| **PaddleOCR**      | paddleocr.yourdomain.com      | `http://paddleocr:8080`      | ⚠️ Loses Caddy auth  |
| **Portainer**      | portainer.yourdomain.com      | `http://portainer:9000`      | Built-in login      |
| **Postiz**         | postiz.yourdomain.com         | `http://postiz:5000`         | Built-in login      |
| **Prometheus**     | prometheus.yourdomain.com     | `http://prometheus:9090`     | ⚠️ Loses Caddy auth  |
| **Qdrant**         | qdrant.yourdomain.com         | `http://qdrant:6333`         | API key recommended |
| **RAGApp**         | ragapp.yourdomain.com         | `http://ragapp:8000`         | ⚠️ Loses Caddy auth  |
| **RagFlow**        | ragflow.yourdomain.com        | `http://ragflow:80`          | Built-in login      |
| **SearXNG**        | searxng.yourdomain.com        | `http://searxng:8080`        | ⚠️ Loses Caddy auth  |
| **Supabase** ¹     | supabase.yourdomain.com       | `http://kong:8000`           | Built-in login      |
| **WAHA**           | waha.yourdomain.com           | `http://waha:3000`           | API key recommended |
| **Weaviate**       | weaviate.yourdomain.com       | `http://weaviate:8080`       | API key recommended |
| **Welcome Page** ² | welcome.yourdomain.com        | `http://caddy:80`            | ⚠️ Loses Caddy auth  |

**Notes:**
- ¹ Dify and Supabase use external compose files from adjacent directories
- ² Welcome Page is served by Caddy as static content; tunnel proxies through Caddy

**⚠️ Security Warning:**
- Services marked **"Loses Caddy auth"** have basic authentication via Caddy that is bypassed by the tunnel. Use [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/) or keep them internal.
- Services marked **"No auth"** have no protection at all - always use Cloudflare Access for these.
- Services with **"Built-in login"** have their own authentication and are generally safe to expose.
- Services with **"API key recommended"** should be configured with API keys in their settings.

#### 4. Install with Tunnel Support

1. Run the n8n-install as normal:
   ```bash
   sudo bash ./scripts/install.sh
   ```
2. When prompted for **Cloudflare Tunnel Token**, paste your token
3. In the Service Selection Wizard, select **Cloudflare Tunnel** to enable the service
4. Complete the rest of the installation

Note: Providing the token alone does not auto-enable the tunnel; you must enable the "cloudflare-tunnel" profile in the wizard (or add it to `COMPOSE_PROFILES`).

#### 5. Secure Your VPS (Recommended)

After confirming services work through the tunnel:

```bash
# Close web ports (UFW example)
sudo ufw delete allow 80/tcp
sudo ufw delete allow 443/tcp
sudo ufw delete allow 7687/tcp
sudo ufw reload

# Verify only SSH remains open
sudo ufw status
```

### Choosing Between Caddy and Cloudflare Tunnel

You have two options for accessing your services:

| Method                  | Pros                                                                                     | Cons                                                                                      | Best For                |
| ----------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ----------------------- |
| **Caddy (Traditional)** | • Caddy auth features work<br>• Simple subdomain setup<br>• No Cloudflare account needed | • Requires open ports<br>• Server IP exposed<br>• No DDoS protection                      | Local/trusted networks  |
| **Cloudflare Tunnel**   | • No open ports<br>• DDoS protection<br>• IP hiding<br>• Global CDN                      | • Requires Cloudflare account<br>• Loses Caddy auth<br>• Each service needs configuration | Internet-facing servers |

### Adding Cloudflare Access (Optional but Recommended)

For services that lose Caddy's basic auth protection, you can add Cloudflare Access:

1. In **Cloudflare One Dashboard** → **Access** → **Applications** (or **Access controls** → **Applications** depending on your dashboard version)
2. Click **Add an application** → **Self-hosted**
3. Configure:
   - **Application name**: e.g., "Prometheus"
   - **Session Duration**: Set token expiry time
   - Click **Add public hostname** and select your domain
4. Enable your preferred identity providers (Google, GitHub, etc.)
5. Add access policies to control who can access the service
6. Save the application

### 🛡️ Advanced Security with WAF Rules

Cloudflare's Web Application Firewall (WAF) allows you to create sophisticated security rules. This is especially important for **n8n webhooks** which need to be publicly accessible but should be protected from abuse.

#### Creating IP Allow Lists

1. Go to **Cloudflare Dashboard** → **Settings** → **Lists**
2. Click **Create new list**
3. Configure:
   - **List name**: `approved_ip_addresses` (lowercase letters, numbers, underscores only)
   - **Content type**: IP Address
4. Click **Create**, then **Add items** to add IP addresses manually or via CSV upload

#### Protecting n8n Webhooks with WAF Rules

n8n webhooks need special consideration because they must be publicly accessible for external services to trigger workflows, but you want to limit who can access them.

1. **Go to your domain** → **Security** → **WAF** → **Custom rules**
2. Click **Create rule**
3. **Rule name**: "Protect n8n webhooks"
4. **Expression Builder** or use **Edit expression**:

**Example expressions:**

| Rule                                 | Expression                                                                                                                        | Action            |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| Block all except approved IPs        | `(not ip.src in $approved_ip_addresses and http.host contains "yourdomain.com")`                                                  | Block             |
| Protect UI, allow webhooks           | `(http.host eq "n8n.yourdomain.com" and not ip.src in $approved_ip_addresses and not http.request.uri.path contains "/webhook/")` | Block             |
| Restrict webhooks to services        | `(http.host eq "n8n.yourdomain.com" and http.request.uri.path contains "/webhook/" and not ip.src in $webhook_allowed_ips)`       | Block             |
| Challenge suspicious webhook traffic | `(http.host eq "n8n.yourdomain.com" and http.request.uri.path contains "/webhook/")`                                              | Managed Challenge |

#### Common Security Rule Patterns

| Use Case                             | Expression                                                                                                | Action                  | Notes                                  |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------- | ----------------------- | -------------------------------------- |
| **Protect webhooks (CRITICAL)**      | `(http.request.uri.path contains "/webhook" and not ip.src in $webhook_service_ips)`                      | Block                   | Webhooks have NO auth - must restrict! |
| **Protect all services**             | `(not ip.src in $approved_ip_addresses)`                                                                  | Block                   | Strictest - only approved IPs          |
| **Geographic restrictions**          | `(ip.geoip.country ne "US" and ip.geoip.country ne "GB")`                                                 | Block                   | Allow only specific countries          |
| **Block bots on sensitive services** | `(http.host in {"prometheus.yourdomain.com" "grafana.yourdomain.com"} and cf.bot_management.score lt 30)` | Block                   | Blocks likely bots                     |
| **Moderate UI protection**           | `(not http.request.uri.path contains "/webhook" and cf.threat_score gt 30)`                               | Managed Challenge       | UI has login, less strict              |
| **Rate limit webhooks**              | `(http.request.uri.path contains "/webhook/")`                                                            | Rate Limit (10 req/min) | Additional webhook protection          |
| **Separate webhook types**           | `(http.request.uri.path contains "/webhook/stripe" and not ip.src in $stripe_ips)`                        | Block                   | Service-specific webhook protection    |

#### Service-Specific Security Strategies

**n8n (CRITICAL):** Webhooks have NO auth and can trigger powerful workflows.
```
# Webhook protection - only from known service IPs
(http.host eq "n8n.yourdomain.com" and
 http.request.uri.path contains "/webhook" and
 not ip.src in $webhook_service_ips)
Action: Block
```

**Flowise:** Protect API endpoints while allowing public chatbot access.
```
(http.host eq "flowise.yourdomain.com" and
 http.request.uri.path contains "/api/" and
 not ip.src in $api_allowed_ips)
Action: Block
```

**Monitoring (Grafana/Prometheus):** Use strict IP allowlists.
```
(http.host in {"grafana.yourdomain.com" "prometheus.yourdomain.com"} and
 not ip.src in $monitoring_team_ips)
Action: Block
```

#### Managing Multiple IP Lists

Create separate lists for different access levels:

| List Name               | Purpose                     | Example IPs                   |
| ----------------------- | --------------------------- | ----------------------------- |
| `approved_ip_addresses` | General admin access        | Office IPs, VPN endpoints     |
| `webhook_allowed_ips`   | Services that call webhooks | Stripe, GitHub, Slack servers |
| `monitoring_team_ips`   | DevOps team access          | Team member home IPs          |
| `api_consumer_ips`      | Third-party API access      | Partner service IPs           |

#### Webhook Security Best Practices

⚠️ **CRITICAL**: Webhooks have NO authentication and can execute powerful workflows. Always protect them with IP allowlists.

**Key Protection Steps:**
1. **Use IP allowlists** - Only allow IPs from services that need webhook access (GitHub, Stripe, etc.)
2. **Use unique webhook paths** - e.g., `/webhook/prod-abc123` instead of guessable URLs
3. **Verify signatures** - Check HMAC signatures from GitHub/Stripe in your n8n workflows
4. **Add rate limiting** - Prevent abuse even from approved IPs
5. **Monitor regularly** - Check Cloudflare Analytics → Security → Events for blocked attempts

#### Testing Your Rules

1. **Use Cloudflare's Trace Tool**:
   - Go to **Account Home** → **Trace**
   - Enter test URLs and IPs
   - See which rules would trigger

2. **Start with Log mode**:
   - Set initial action to "Log" instead of "Block"
   - Monitor for false positives
   - Switch to "Block" after verification

3. **Test webhook access**:
   ```bash
   # Test from allowed IP
   curl -X POST https://n8n.yourdomain.com/webhook/test-webhook
   
   # Test from non-allowed IP (should be blocked)
   curl -X POST https://n8n.yourdomain.com/admin
   ```

#### Important Considerations

- **Webhook IPs can change**: Services like GitHub, Stripe publish their webhook IP ranges - keep your lists updated
- **Development vs Production**: Consider separate rules for development environments
- **Bypass for emergencies**: Keep a "break glass" rule you can quickly enable for emergency access
- **Logging**: Enable logging on security rules to track access patterns

### Verifying Tunnel Connection

#### Step 1: Check tunnel container is running

```bash
docker compose -p localai ps cloudflared
docker compose -p localai logs cloudflared --tail 20
```

You should see:
```
INF Registered tunnel connection connIndex=0 ... location=xxx protocol=quic
INF Registered tunnel connection connIndex=1 ... location=xxx protocol=quic
INF Updated to new configuration
```

#### Step 2: Verify traffic goes through Cloudflare

This is the most important check — confirms your domain uses the tunnel, not direct connection:

```bash
# Check for Cloudflare headers
curl -sI https://yourdomain.com | grep -iE '^(cf-|server:)'
```

**✅ Working through Cloudflare** — you'll see:
```
server: cloudflare
cf-ray: 8a1b2c3d4e5f6g7h-YYZ
```

**❌ NOT through Cloudflare** — you'll see:
```
server: Caddy
```
or no `cf-ray` header at all.

#### Step 3: Check DNS resolution

```bash
# Should return Cloudflare IPs, NOT your server IP
dig +short yourdomain.com

# Quick check: is it Cloudflare? (requires whois: apt install whois)
whois $(dig +short yourdomain.com | head -1) 2>/dev/null | grep -i cloudflare
```

If you see your server's IP (e.g., `137.184.x.x`), DNS is not configured correctly.

#### Quick one-liner test

```bash
curl -sI https://yourdomain.com 2>/dev/null | grep -q "cf-ray" && echo "✓ Traffic goes through Cloudflare Tunnel" || echo "✗ Traffic goes DIRECTLY to server (tunnel not working)"
```

**Note**: This test requires `curl` and a working HTTPS connection. If you're debugging early setup before SSL is working, use `dig` commands from Step 3 instead.

#### Common issues if verification fails

| Symptom | Cause | Solution |
|---------|-------|----------|
| No `cf-ray` header | DNS points to server IP | Transfer DNS to Cloudflare or create CNAME |
| `server: Caddy` | Traffic bypasses tunnel | Check DNS, delete A records for subdomains |
| Tunnel connected but no traffic | Missing public hostname | Add hostname in Zero Trust dashboard |
| DNS shows server IP | Nameservers not updated | Update NS records at registrar |

### Troubleshooting

**Tunnel running but traffic goes directly to server (no `cf-ray` header):**
- **Most common cause**: DNS is managed outside Cloudflare (e.g., DigitalOcean, GoDaddy)
- **Solution**: Transfer DNS to Cloudflare (see "DNS Configuration" section above)
- **Quick check**: `dig NS yourdomain.com +short` — should show `xxx.ns.cloudflare.com`
- If DNS is external, you must create CNAME records manually pointing to `<tunnel-id>.cfargotunnel.com`

**"Too many redirects" error:**
- Make sure you're pointing to the service directly (e.g., `http://n8n:5678`), NOT to Caddy
- Verify the service URL uses HTTP, not HTTPS
- Check that DNS records have Proxy status ON (orange cloud)

**"Server not found" error:**
- Verify DNS records exist for your subdomain
- Check tunnel is healthy in Cloudflare dashboard
- Ensure tunnel token is correct in `.env`

**Services not accessible:**
- Verify tunnel status: `docker ps | grep cloudflared`
- Check tunnel logs: `docker logs cloudflared`
- Ensure the service is running: `docker ps`
- Verify service name and port in tunnel configuration

**"ERR Cannot determine default origin certificate path":**
- This warning in logs is normal for token-based tunnels
- Does not affect functionality — tunnel still works

**Tunnel unstable or failing to connect (QUIC/UDP blocked):**
- Some ISPs and firewalls block UDP traffic, which the QUIC protocol requires
- **Solution**: Set `CLOUDFLARE_TUNNEL_PROTOCOL=http2` in `.env` (uses TCP instead) and recreate the tunnel:
  ```bash
  docker compose -p localai up -d --force-recreate cloudflared
  ```
- Valid values: `auto` (default, prefers QUIC and falls back to HTTP/2 at startup), `quic`, `http2`

**Mixed mode (tunnel + direct access):**
- You can run both tunnel and traditional Caddy access simultaneously
- Useful for testing before closing firewall ports
- Simply keep ports 80/443 open until ready to switch fully to tunnel

### Disabling Tunnel

To disable Cloudflare Tunnel and return to Caddy-only access:

1. Remove from compose profiles:
   ```bash
   # Edit .env and remove "cloudflare-tunnel" from COMPOSE_PROFILES
   nano .env
   ```

2. Stop the tunnel and restart services:
   ```bash
   docker compose -p localai --profile cloudflare-tunnel down
   docker compose -p localai up -d
   ```

3. Re-open firewall ports if closed:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw reload
   ```

### Important Notes

1. **Service-to-service communication** remains unchanged - containers still communicate directly via Docker network
2. **Ollama** is not included in the tunnel setup as it's typically used internally only
3. **Database ports** (PostgreSQL, Redis) should never be exposed through the tunnel
4. Consider using **Cloudflare Access** for any services that need authentication