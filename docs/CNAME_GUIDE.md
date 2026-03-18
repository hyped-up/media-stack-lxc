# CNAME Records Guide (Beginner-Friendly)

## The Simple Explanation

**CNAME = A nickname for a domain**

Instead of pointing `plex.yourdomain.com` directly to an IP address, you point it to `yourdomain.com`, and then `yourdomain.com` points to the IP.

### Real-World Analogy

Think of it like mail forwarding:
- Your main address: `yourdomain.com` → 123 Main St
- CNAME records: "Mail to plex.yourdomain.com? Forward it to yourdomain.com"

All your subdomains forward to the same address. Change the main address once, and everything updates.

---

## Why Do We Use CNAMEs Here?

### Without CNAMEs (the old way):
```
plex.yourdomain.com     → 192.168.1.100
sonarr.yourdomain.com   → 192.168.1.100
radarr.yourdomain.com   → 192.168.1.100
```

If your IP changes, update **every single record**.

### With CNAMEs:
```
plex.yourdomain.com     → yourdomain.com
sonarr.yourdomain.com   → yourdomain.com
radarr.yourdomain.com   → yourdomain.com
yourdomain.com          → Cloudflare (they handle the rest)
```

Change IP once, everything works. Plus, you get Cloudflare's protection.

---

## How This Setup Actually Works

Let's trace what happens when someone visits `https://plex.yourdomain.com`:

### Step 1: DNS Lookup
```
Browser: "What's the IP for plex.yourdomain.com?"
DNS: "That's a CNAME. Let me check yourdomain.com..."
DNS: "yourdomain.com points to 104.21.x.x (Cloudflare)"
Browser: "Got it, connecting to 104.21.x.x"
```

### Step 2: Through Cloudflare
```
Browser connects to Cloudflare Edge server (104.21.x.x)
Cloudflare: "plex.yourdomain.com? I have a tunnel for that..."
Cloudflare sends traffic through encrypted tunnel to your home
```

### Step 3: Into Your Server
```
Cloudflared container receives: "Someone wants plex.yourdomain.com"
Sends to Traefik: "Here's a request for plex.yourdomain.com"
```

### Step 4: Traefik Routes It
```
Traefik checks its routing rules:
"plex.yourdomain.com → Send to Plex container on port 32400"
Traefik forwards request to Plex
Plex responds
```

**The magic:** All services share one IP (Cloudflare's), but Traefik knows which container to send each request to based on the domain name.

---

## Setting Up CNAMEs (Step-by-Step)

### What You'll Need
- Domain registered (any registrar)
- Domain moved to Cloudflare DNS (free)
- 5 minutes

### Step 1: Log Into Cloudflare
Go to [dash.cloudflare.com](https://dash.cloudflare.com) and select your domain.

### Step 2: Add One Wildcard CNAME

Click **DNS** → **Add record**

Fill in:
- **Type:** CNAME
- **Name:** `*` (that's an asterisk - means "any subdomain")
- **Target:** `yourdomain.com` (your root domain)
- **Proxy status:** Click the cloud icon until it's **orange** (Proxied)
- **TTL:** Auto

Click **Save**

**What this does:** Any subdomain (`plex`, `sonarr`, `anything`) will point to `yourdomain.com`.

### Step 3: Verify It Worked

Open terminal (or Command Prompt on Windows):

```bash
nslookup plex.yourdomain.com
```

You should see Cloudflare IPs (`104.x.x.x` or `172.x.x.x`).

**Not seeing Cloudflare IPs?** Wait 5-10 minutes for DNS to update. Try `nslookup yourdomain.com` to check if the domain is even on Cloudflare yet.

---

## Understanding Traefik Routing

Traefik is your "traffic cop" - it sees the domain name in each request and routes it to the right container.

### How Traefik Knows Where to Send Traffic

Each Docker container has labels that tell Traefik its domain:

```yaml
plex:
  labels:
    - "traefik.http.routers.plex.rule=Host(`plex.yourdomain.com`)"
```

This means: "If someone visits `plex.yourdomain.com`, send them to the Plex container."

### All Services on One IP - How?

It's the **hostname** that matters, not the IP:

```
Request: GET / HTTP/1.1
Host: plex.yourdomain.com  ← Traefik reads this
```

Even though all services go to the same IP (Cloudflare's), the `Host` header tells Traefik which container to route to.

**It's like apartment buildings:**
- Building address: 123 Main St (the IP)
- Apartment 1: Plex
- Apartment 2: Sonarr
- Apartment 3: Radarr

The mail carrier (Traefik) reads the apartment number (hostname) and delivers to the right door.

---

## Common Questions

### Q: Why not just use IP addresses?

**A:** Three reasons:

1. **Your home IP changes** (unless you pay for static IP)
2. **Can't have multiple services on port 443** without domain routing
3. **No SSL certificates** without domain names (Let's Encrypt needs a domain)

### Q: Do I need a CNAME for every service?

**A:** No! The wildcard (`*`) handles everything:
- `plex.yourdomain.com` ✅
- `sonarr.yourdomain.com` ✅
- `brand-new-service.yourdomain.com` ✅

Just add the Traefik labels to the new container, and it works instantly.

### Q: What if I misspell a subdomain?

**A:** With wildcard CNAME, even `typo.yourdomain.com` will resolve to Cloudflare. But Traefik won't have a route for it, so you'll get a 404.

**Not a security issue** - just means unused subdomains go to Cloudflare, then get rejected by Traefik.

### Q: Can I use this without Cloudflare?

**A:** Yes, but:
- You'll need to forward ports 80 and 443 on your router
- Your home IP will be visible
- No DDoS protection
- Need dynamic DNS if your IP changes

Cloudflare is free and makes everything easier.

---

## Troubleshooting

### DNS Not Resolving

**Check:**
```bash
# Does your domain point to Cloudflare?
nslookup yourdomain.com
# Should show 104.x.x.x or 172.x.x.x (Cloudflare IPs)

# Does your subdomain resolve?
nslookup plex.yourdomain.com
# Should also show Cloudflare IPs
```

**If it doesn't:**
1. Is your domain using Cloudflare nameservers? (Check registrar)
2. Wait longer (DNS can take up to 24 hours, usually 5-10 minutes)
3. Try `nslookup plex.yourdomain.com 1.1.1.1` (force Cloudflare DNS)

### Getting 404 Errors

**DNS works, but website shows 404:**

1. **Check Cloudflare Tunnel is running:**
   ```bash
   docker logs cloudflared
   # Should say "Registered tunnel connection"
   ```

2. **Check Traefik sees the service:**
   ```bash
   docker logs traefik | grep plex
   # Should show routing rule
   ```

3. **Check container is running:**
   ```bash
   docker ps | grep plex
   ```

### SSL Certificate Errors

**Getting "Your connection is not private":**

This means Traefik hasn't gotten a certificate yet.

**Check Traefik logs:**
```bash
docker logs traefik | grep -i certificate
```

**Common causes:**
- Cloudflare API token is wrong
- Domain not fully on Cloudflare yet
- Let's Encrypt rate limit (wait 1 hour)

**Fix:** Restart Traefik after fixing:
```bash
docker restart traefik
```

---

## Visual Summary

```
┌──────────────────────────────────────────┐
│  User types: plex.yourdomain.com         │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  DNS: plex.yourdomain.com                │
│  →  CNAME → yourdomain.com               │
│  →  A Record → 104.21.x.x (Cloudflare)   │
└──────────────┬───────────────────────────┘
               │
               ▼ Encrypted Tunnel
┌──────────────────────────────────────────┐
│  Your Server (LXC Container)             │
│                                          │
│  ┌────────────┐                         │
│  │ cloudflared│ ← Receives traffic      │
│  └─────┬──────┘                         │
│        │                                 │
│        ▼                                 │
│  ┌────────────┐                         │
│  │  Traefik   │ ← Reads hostname        │
│  └─────┬──────┘   "plex.yourdomain.com"│
│        │                                 │
│    ┌───┴─────┬────────┬──────┐         │
│    ▼         ▼        ▼      ▼         │
│  ┌────┐  ┌──────┐ ┌──────┐ ┌────┐     │
│  │Plex│  │Sonarr│ │Radarr│ │... │     │
│  └────┘  └──────┘ └──────┘ └────┘     │
└──────────────────────────────────────────┘
```

**The key insight:** DNS gets you to Cloudflare, Cloudflare Tunnel gets you to your server, and Traefik routes to the right container - all based on the domain name.

---

## Quick Setup Checklist

- [ ] Domain moved to Cloudflare DNS
- [ ] Wildcard CNAME added (`*` → `yourdomain.com`)
- [ ] Proxy status = Proxied (orange cloud)
- [ ] Test: `nslookup plex.yourdomain.com` returns Cloudflare IP
- [ ] Cloudflare Tunnel created and token copied
- [ ] Ran media-stack-lxc installer with tunnel token
- [ ] Test: `https://plex.yourdomain.com` loads with valid SSL

**Done!** All future services just need Traefik labels in docker-compose.

---

## When Things Go Wrong

**99% of issues are:**
1. DNS not propagated yet (wait longer)
2. Cloudflare Tunnel not connected (check `docker logs cloudflared`)
3. Traefik routing rule missing (check container labels)
4. Container not running (check `docker ps`)

**Debug order:**
1. DNS resolving? → Check `nslookup`
2. Tunnel connected? → Check `docker logs cloudflared`
3. Traefik routing? → Check `docker logs traefik`
4. Container healthy? → Check `docker ps`

Start from the top, work down. Usually fixes itself once DNS propagates.

---

## Need Help?

- Check our guides: [docs/](./README.md#documentation)
- Open an issue: [github.com/hyped-up/media-stack-lxc/issues](https://github.com/hyped-up/media-stack-lxc/issues)
- Discord: [Link if you set one up]

You've got this! 🚀
