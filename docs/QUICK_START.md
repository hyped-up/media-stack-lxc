# Quick Start Guide

## 5-Minute Deployment

### Prerequisites
- Proxmox VE 7.0+
- Basic networking knowledge
- Domain name (for HTTPS)
- (Optional) NAS for media storage

### Step 1: Create LXC Container

On your Proxmox host:

```bash
# Download Debian 12 template (if not already available)
pveam update
pveam download local debian-12-standard_12.7-1_amd64.tar.zst

# Create unprivileged container
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

# Enter container console
pct enter 200
```

**Container ID 200** — change this if you have an existing container with that ID.

### Step 2: Run Installer

Inside the LXC container:

```bash
# Update system
apt update && apt upgrade -y

# Download installer
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/media-stack-lxc/main/install.sh -o /tmp/install.sh

# Make executable
chmod +x /tmp/install.sh

# Run installer
/tmp/install.sh
```

The interactive wizard will start automatically.

### Step 3: Answer Wizard Questions

The TUI will ask for:

#### 1. Domain Name
```
Enter your base domain (e.g., hypebeastin.com):
> yourdomain.com
```

All services will be at `service.yourdomain.com` (e.g., `plex.yourdomain.com`).

#### 2. Cloudflare Tunnel (Recommended)
```
Do you want to use Cloudflare Tunnel for external access?
> Yes
```

Get your tunnel token from:
1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. Networks → Tunnels → Create Tunnel
3. Copy the token

#### 3. Plex Claim Token (Optional)
```
Enter your Plex claim token:
> claim-XXXXXX
```

Get from: [https://plex.tv/claim](https://plex.tv/claim)

(Valid for 4 minutes, so generate it right before this step)

#### 4. Storage
```
Do you want to mount NFS storage from a NAS?
> Yes

NAS IP address:
> 10.0.0.8

NFS media path:
> /mnt/tank0/media

NFS downloads path:
> /mnt/tank0/downloads
```

If **No**: uses local storage at `/opt/media` and `/opt/downloads`.

#### 5. Services

Select what you want (use Space to toggle):

```
[X] sonarr       TV show automation
[X] radarr       Movie automation
[X] prowlarr     Indexer manager
[X] bazarr       Subtitle automation
[ ] lidarr       Music automation
[X] sabnzbd      Usenet downloader
[X] qbittorrent  Torrent client
[X] overseerr    Media requests
[X] tautulli     Plex monitoring
[X] dozzle       Log viewer
[X] heimdall     Dashboard
```

Recommended minimum: Plex + Sonarr + Radarr + Prowlarr + SABnzbd

#### 6. GPU Transcoding
```
Hardware Transcoding:
> Intel QuickSync (/dev/dri)
```

Options:
- **CPU only** — software transcoding (works everywhere, slower)
- **Intel QuickSync** — /dev/dri passthrough (fast, low power)
- **NVIDIA** — requires GPU passthrough + nvidia-docker2

### Step 4: Wait for Install

The installer will:

1. Install Docker
2. Configure firewall (UFW)
3. Mount NFS shares (if selected)
4. Generate Docker Compose stack
5. Download all container images
6. Start services

**Time: 5-10 minutes** (depending on internet speed)

### Step 5: Access Services

When complete, you'll see:

```
╔════════════════════════════════════════╗
║   Media Stack Installation Complete   ║
╚════════════════════════════════════════╝

Services accessible at:

  • Plex:      https://plex.yourdomain.com
  • Portainer: https://portainer.yourdomain.com
  • Sonarr:    https://sonarr.yourdomain.com
  • Radarr:    https://radarr.yourdomain.com
  ...
```

## Post-Install Configuration

### 1. Plex Setup

1. Go to `https://plex.yourdomain.com/web`
2. Sign in with your Plex account
3. **Add Library** → Movies → `/media/movies`
4. **Add Library** → TV Shows → `/media/tv`
5. Settings → Transcoder → **Enable hardware acceleration**

### 2. Prowlarr (Indexer Management)

1. Go to `https://prowlarr.yourdomain.com`
2. Settings → Indexers → **Add Indexer**
   - Add your Usenet indexers (e.g., NZBgeek, DrunkenSlug)
   - Add torrent indexers (e.g., 1337x, RARBG alternatives)
3. Settings → Apps → **Add Application**
   - Add Sonarr (API key from `https://sonarr.yourdomain.com/settings/general`)
   - Add Radarr (API key from `https://radarr.yourdomain.com/settings/general`)

Now all indexers sync to Sonarr/Radarr automatically!

### 3. Download Clients

#### SABnzbd (Usenet)
1. Go to `https://sabnzbd.yourdomain.com`
2. Settings → Servers → **Add Server**
   - Enter your Usenet provider details
3. Settings → Folders
   - Temporary Download Folder: `/downloads/incomplete`
   - Completed Download Folder: `/downloads/complete`

#### Sonarr/Radarr Integration
1. Sonarr → Settings → Download Clients → **Add SABnzbd**
   - Host: `sabnzbd` (Docker network name)
   - Port: `8080`
   - API Key: (from SABnzbd settings)
2. Repeat for Radarr

### 4. Test the Stack

1. **Radarr**: Search for a movie → Add → Monitor
2. Watch Prowlarr search indexers
3. Watch SABnzbd download
4. Watch Radarr import to `/media/movies`
5. See it appear in Plex within 5 minutes!

## Troubleshooting

### Services won't start
```bash
cd /opt/docker
docker compose logs -f
```

### Can't access via HTTPS
Check Cloudflare Tunnel:
```bash
docker logs cloudflared -f
```

Verify DNS:
```bash
nslookup plex.yourdomain.com
```

### NFS mount failed
```bash
# Test mount
mount -a

# Check logs
journalctl -xe | grep mount

# Verify NAS reachable
ping 10.0.0.8
```

### Plex won't transcode
Check GPU passthrough:
```bash
# Intel QuickSync
docker exec plex ls -la /dev/dri
# Should see: renderD128

# NVIDIA
docker exec plex nvidia-smi
```

## Next Steps

- **Overseerr**: User-friendly request interface for Plex users
- **Tautulli**: Monitor who's watching what, generate stats
- **Heimdall**: Beautiful dashboard for all services
- **Authentik**: Add SSO to protect everything (advanced)

Full documentation: [docs/ARCHITECTURE.md](ARCHITECTURE.md)

---

**You now have a production-grade media server. Enjoy! 🍿**
