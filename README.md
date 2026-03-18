# Media Stack LXC - Automated Proxmox Container

Complete automation to deploy a production-ready media server stack in a Proxmox LXC container.

## What This Does

Deploys a **fully configured media server** with:

### Core Services
- **Plex** — Media streaming server
- **Traefik** — Reverse proxy with automatic HTTPS
- **Portainer** — Docker management UI
- **Cloudflared** — Cloudflare Tunnel for secure external access

### Media Automation (*arr stack)
- **Sonarr** — TV show automation
- **Radarr** — Movie automation  
- **Prowlarr** — Indexer manager
- **Bazarr** — Subtitle automation
- **Lidarr** — Music automation (optional)

### Download Clients
- **SABnzbd** — Usenet downloader
- **qBittorrent** — Torrent client

### Management & Monitoring
- **Tautulli** — Plex monitoring & stats
- **Seerr** — Modern media request management (Overseerr fork)
- **Ombi** — Alternative media request platform
- **Dozzle** — Container log viewer

## Features

✅ **Interactive TUI wizard** — Simple checkbox selection, sensible defaults  
✅ **One-command deployment** — Just run the installer  
✅ **Automatic HTTPS** — Let's Encrypt via Traefik  
✅ **Hardware transcoding** — Intel QuickSync / NVIDIA GPU support  
✅ **NFS auto-mount** — Connect to existing NAS storage  
✅ **UFW firewall** — Secure by default  
✅ **Docker Compose** — All services as code  
✅ **Idempotent** — Safe to re-run, won't duplicate services  
✅ **Smart defaults** — 1080p quality, proper paths, optimized settings  

## Architecture

Based on the battle-tested **cpdock1** production stack:

```
Internet
  │
  ▼
Cloudflare Tunnel (cloudflared)
  │
  ▼
Traefik (reverse proxy)
  │
  ├─► Plex
  ├─► Sonarr / Radarr / Prowlarr
  ├─► SABnzbd / qBittorrent
  ├─► Overseerr
  ├─► Portainer
  └─► Tautulli / Dozzle
```

All services on isolated Docker network (`proxy`), secured with Traefik TLS.

## Documentation

- [Quick Start Guide](docs/QUICK_START.md) - 5-minute deployment
- [**Cloudflare Setup**](docs/CLOUDFLARE_SETUP.md) - Why Cloudflare + complete setup instructions
- [Wizard Walkthrough](docs/WIZARD_WALKTHROUGH.md) - Visual guide to installer


## Quick Start

### 1. Create Proxmox LXC Container

```bash
# On Proxmox host:
pct create 200 \
  local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname mediastack \
  --memory 8192 \
  --swap 2048 \
  --cores 4 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:50 \
  --unprivileged 1 \
  --features nesting=1

# Start container
pct start 200

# Enter container
pct enter 200
```

### 2. Run Installer

```bash
# Inside LXC:
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/media-stack-lxc/main/install.sh | bash
```

The TUI wizard will guide you through:
1. Domain configuration
2. Cloudflare Tunnel setup (optional)
3. Plex claim token (optional)
4. Storage: NFS or local
5. Service selection (checkboxes - pick what you want)
6. GPU transcoding type

**All services use sensible defaults:**
- 1080p quality profiles
- Proper media paths (/media/tv, /media/movies)
- Full Prowlarr sync to *arr apps
- English subtitles (Bazarr)
- Standard ports

### 3. Access Services

After deployment (5-10 minutes):

- **Plex**: `https://plex.yourdomain.com`
- **Seerr**: `https://seerr.yourdomain.com`
- **Portainer**: `https://portainer.yourdomain.com`

All services listed in the final installer output.

## File Structure

```
media-stack-lxc/
├── README.md              # This file
├── install.sh             # Main installer script
├── lib/
│   ├── tui.sh            # Dialog-based UI functions
│   ├── docker.sh         # Docker install & setup
│   ├── network.sh        # Firewall & network config
│   └── services.sh       # Service provisioning
├── templates/
│   ├── traefik.yml       # Traefik static config template
│   ├── docker-compose/
│   │   ├── core.yml      # Traefik + Cloudflared + Portainer
│   │   ├── plex.yml      # Plex with GPU passthrough
│   │   ├── arr.yml       # Sonarr/Radarr/Prowlarr/Bazarr
│   │   ├── download.yml  # SABnzbd + qBittorrent
│   │   └── extras.yml    # Overseerr/Tautulli/Dozzle/Heimdall
│   └── env/
│       ├── .env.template # Master environment template
│       └── service-specific templates
└── docs/
    ├── DEPLOYMENT.md     # Deployment guide
    ├── TROUBLESHOOTING.md # Common issues
    └── ARCHITECTURE.md   # Technical deep-dive
```

## System Requirements

### Minimum
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 30 GB
- **OS**: Debian 12 / Ubuntu 22.04+

### Recommended
- **CPU**: 4+ cores (Intel with QuickSync ideal)
- **RAM**: 8 GB
- **Disk**: 50 GB SSD (OS + Docker images)
- **Storage**: NFS mount to NAS (media library)
- **Network**: 1 Gbps LAN

### For Hardware Transcoding
- **Intel**: /dev/dri device passthrough (QuickSync)
- **NVIDIA**: GPU passthrough + nvidia-docker2

## Configuration Files

After installation, all config lives in:

```
/opt/docker/
├── .env                  # Master environment file
├── docker-compose.yml    # Main compose stack
├── traefik/
│   └── config/
│       ├── traefik.yml   # Static config
│       ├── config.yml    # File provider (routes)
│       └── acme.json     # TLS certificates
└── [service]/
    ├── config/           # Service-specific config
    └── .env             # Service secrets (optional)
```

## Post-Install

### 1. Plex
1. Go to `https://plex.yourdomain.com/web`
2. Sign in with Plex account
3. Add library → point to `/media/tv`, `/media/movies`
4. Settings → Transcoder → Enable hardware transcoding

### 2. Prowlarr (Indexer Management)
1. Go to `https://prowlarr.yourdomain.com`
2. Settings → Indexers → Add your Usenet/torrent indexers
3. Settings → Apps → Add Sonarr/Radarr (they auto-sync!)

### 3. Seerr (Media Requests)
1. Go to `https://seerr.yourdomain.com`
2. Sign in with Plex
3. Connect to Sonarr/Radarr
4. Share with users for easy requests

### 4. Download Clients
**SABnzbd:**
- Settings → Servers → Add your Usenet provider
- Folders already configured: `/downloads/complete`, `/downloads/incomplete`

**Sonarr/Radarr:**
- Settings → Download Clients → Add SABnzbd
- Host: `sabnzbd` (Docker network)
- Port: `8080`

All paths pre-configured:
- `/downloads` → Download output
- `/media/tv` → Sonarr
- `/media/movies` → Radarr
- `/media/music` → Lidarr

## Troubleshooting

### Container won't start
```bash
# Check Docker status
systemctl status docker

# View logs
journalctl -u docker -n 50
```

### Services unreachable
```bash
# Check Traefik logs
docker logs traefik -f

# Verify Cloudflare tunnel
docker logs cloudflared -f

# Check container health
docker ps -a
```

### NFS mounts failing
```bash
# Test mount
mount -a
df -h | grep nfs

# Check NAS reachability
ping YOUR_NAS_IP
```

Full troubleshooting guide: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Updating Services

```bash
cd /opt/docker
docker-compose pull
docker-compose up -d
```

## Backup & Restore

### Backup
```bash
/opt/docker/scripts/backup.sh
# Creates: /mnt/backup/docker-backup-YYYY-MM-DD.tar.gz
```

### Restore
```bash
tar -xzf docker-backup-YYYY-MM-DD.tar.gz -C /opt/docker
cd /opt/docker
docker-compose up -d
```

## Security

- All external traffic via Cloudflare Tunnel (no open ports)
- Traefik handles TLS termination (Let's Encrypt)
- UFW firewall blocks everything except SSH
- Services isolated on `proxy` Docker network
- No default passwords (wizard enforces custom)

## Credits

Based on the **cpdock1** production media server architecture by Lee Keneston.

Optimized for:
- Proxmox LXC deployment
- One-command automation
- Best practices from real production workloads

## License

MIT

---

**Ready to deploy your own media empire? Let's go. 🚀**

### Advanced Services

#### Notifiarr (Optional)
**⚠️ Complex Setup Required**

Notifiarr provides Discord notifications for your media stack (new downloads, requests, server issues, etc.).

**Why it's marked advanced:**
- Requires Notifiarr account + API key
- Needs Discord webhook configuration
- Must configure per-app integrations
- Can be overwhelming for beginners

**Post-install steps:**
1. Sign up at [notifiarr.com](https://notifiarr.com)
2. Get API key from dashboard
3. Add to `/opt/docker/.env`: `NOTIFIARR_API_KEY=your_key`
4. Configure Discord webhooks
5. Connect to Sonarr/Radarr/etc in Notifiarr dashboard

**Recommended:** Skip during initial setup, add later once your stack is stable.
