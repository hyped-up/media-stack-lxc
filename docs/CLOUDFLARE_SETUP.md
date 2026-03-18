# Cloudflare Setup Guide

## Why Cloudflare?

This installer uses Cloudflare for two critical functions:

### 1. Cloudflare Tunnel (Secure Remote Access)
**What it does:** Provides HTTPS access to your services from anywhere **without opening ports** on your router.

**Why this matters:**
- ✅ **No port forwarding** — Your home IP stays hidden
- ✅ **No firewall holes** — Nothing exposed to the internet directly
- ✅ **DDoS protection** — Cloudflare's edge network shields your server
- ✅ **Automatic HTTPS** — Encrypted tunnel from Cloudflare to your server
- ✅ **Works behind CGNAT** — Even if your ISP blocks port 80/443

**Traditional method problems:**
```
Internet → Your Router:443 (port forward) → Your Server
```
- Exposes your home IP
- Opens attack surface
- Requires static IP or DDNS
- Port 80/443 might be blocked by ISP

**Cloudflare Tunnel method:**
```
Internet → Cloudflare Edge → Encrypted Tunnel → Your Server
```
- Zero open ports
- Home IP hidden
- Works on any network

### 2. Traefik Certificate Management (Let's Encrypt)
**What it does:** Automatically obtains and renews SSL certificates for all your services.

**Why Cloudflare DNS-01 challenge:**
- ✅ **Works with private servers** — No need for port 80 to be publicly accessible
- ✅ **Wildcard certificates** — One cert for \`*.yourdomain.com\`
- ✅ **Auto-renewal** — Traefik handles everything
- ✅ **No rate limits** — DNS challenges don't hit Let's Encrypt as hard

---

## Complete Setup Flow

See the full architecture diagram in the repo.

**Summary:** Internet → Cloudflare Edge → Tunnel → Traefik → Services

---

## Prerequisites

1. **Domain name** registered (any registrar works)
2. **Free Cloudflare account** at cloudflare.com
3. **Domain transferred to Cloudflare DNS**

---

## Step-by-Step Setup

### Part 1: Move Domain to Cloudflare DNS

1. Log in to dash.cloudflare.com
2. Click **Add a Site** → Enter your domain
3. Select **Free Plan**
4. Update nameservers at your registrar (Cloudflare will show you which ones)
5. Wait 5-60 minutes for DNS propagation

### Part 2: Create Cloudflare Tunnel

1. Go to one.dash.cloudflare.com
2. Networks → **Tunnels** → **Create a tunnel**
3. Name it (e.g., "media-stack-lxc")
4. **Copy the tunnel token** - you'll need this during installation
5. Add public hostname routes:
   - Subdomain: \`*\` (wildcard)
   - Domain: yourdomain.com
   - Service: \`http://traefik:80\`

### Part 3: Cloudflare API Token (For SSL Certificates)

1. Go to dash.cloudflare.com → **My Profile** → **API Tokens**
2. **Create Token** → Use **Edit zone DNS** template
3. Permissions: Zone/DNS/Edit + Zone/Zone/Read
4. Zone: yourdomain.com
5. **Copy the API token** - you'll need this during installation

---

## During Installation

The wizard will prompt for:

1. **Cloudflare Tunnel Token** - from Part 2, Step 4
2. **Cloudflare API Token** - from Part 3, Step 5

Both get stored in \`/opt/docker/.env\` automatically.

---

## How It Works

### Cloudflare Tunnel
- Establishes encrypted connection from your LXC to Cloudflare
- No ports opened on your router
- Traffic: User → Cloudflare Edge → Tunnel → Your Server

### Traefik + Let's Encrypt
- Traefik requests SSL cert from Let's Encrypt
- Uses Cloudflare API to complete DNS-01 challenge
- Automatically renews every 60 days
- Result: Valid HTTPS for all services

---

## Verification

After installation:

\`\`\`bash
# Check tunnel status
docker logs cloudflared -f

# Check certificates
docker logs traefik | grep -i certificate

# Test HTTPS
curl -I https://plex.yourdomain.com
\`\`\`

---

## Troubleshooting

### Tunnel Not Connecting
- Check token is correct
- Verify tunnel is active in Cloudflare dashboard
- Check logs: \`docker logs cloudflared\`

### Certificates Not Issuing
- Verify API token permissions
- Check DNS is using Cloudflare nameservers
- Wait for rate limits (1 hour)
- Check logs: \`docker logs traefik | grep acme\`

### Services Return 404
- Verify Traefik routing: \`docker exec traefik cat /config/config.yml\`
- Check service labels: \`docker inspect plex | grep traefik\`

---

## Security

**What Cloudflare protects:**
- Hides your home IP
- DDoS protection
- Web Application Firewall (WAF)
- Bot protection

**What you should still do:**
- Keep services updated
- Use strong passwords
- UFW firewall (installer enables this)
- Consider Authentik SSO for additional protection

---

## Alternative: No Cloudflare Tunnel

If you choose NO during setup:
- Requires port forwarding (80, 443)
- Home IP exposed
- Uses HTTP-01 challenge instead of DNS-01
- Slightly faster (direct connection)

---

## Summary

**Cloudflare Tunnel** = Zero open ports + secure remote access  
**Traefik + Let's Encrypt** = Automatic HTTPS certificates

Together: Secure, easy media server access from anywhere.

Questions? https://github.com/hyped-up/media-stack-lxc/issues
