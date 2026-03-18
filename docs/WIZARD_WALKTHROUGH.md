# TUI Wizard Walkthrough

## Complete step-by-step guide through the interactive installer

### Screen 1: Welcome

```
┌────────── Media Stack LXC Installer ──────────┐
│                                               │
│  Welcome to the automated media server        │
│  installer!                                   │
│                                               │
│  This wizard will deploy a complete Plex      │
│  media stack with:                            │
│                                               │
│  • Plex Media Server                          │
│  • Sonarr / Radarr / Prowlarr                 │
│  • SABnzbd / qBittorrent                      │
│  • Traefik reverse proxy                      │
│  • Cloudflare Tunnel                          │
│  • Portainer management                       │
│                                               │
│  Based on the battle-tested cpdock1           │
│  architecture.                                │
│                                               │
│  Press OK to begin.                           │
│                                               │
│              < OK >                            │
└───────────────────────────────────────────────┘
```

### Screen 2: Domain Configuration

```
┌────────── Domain Configuration ───────────────┐
│                                               │
│  Enter your base domain (e.g.,                │
│  yourdomain.com):                            │
│                                               │
│  Services will be accessible at:              │
│  • plex.yourdomain.com                        │
│  • sonarr.yourdomain.com                      │
│  • etc.                                       │
│                                               │
│  yourdomain.com___________________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**What you enter:** `yourdomain.com` (your domain)

---

### Screen 3: Cloudflare Tunnel

```
┌────────── Cloudflare Tunnel ──────────────────┐
│                                               │
│  Do you want to use Cloudflare Tunnel for     │
│  external access?                             │
│                                               │
│  This provides secure HTTPS access without    │
│  opening ports.                               │
│                                               │
│  You'll need a Cloudflare account.            │
│                                               │
│              < Yes >    < No >                │
└───────────────────────────────────────────────┘
```

**Select:** Yes (recommended)

---

### Screen 4: Cloudflare Token (if Yes)

```
┌────────── Cloudflare Tunnel Token ────────────┐
│                                               │
│  Enter your Cloudflare Tunnel token:          │
│                                               │
│  (Get this from dash.cloudflare.com →         │
│   Zero Trust → Tunnels)                       │
│                                               │
│  eyJhIjoixxxxxxx...________________           │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**What you enter:** Your Cloudflare Tunnel token from [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)

---

### Screen 5: Plex Claim Token

```
┌────────── Plex Claim Token ───────────────────┐
│                                               │
│  Enter your Plex claim token (optional):      │
│                                               │
│  Get one from: https://plex.tv/claim          │
│                                               │
│  (Leave empty to configure Plex manually      │
│   later)                                      │
│                                               │
│  claim-xxxxxxxxxxxxxxxxxxxx____________       │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**What you enter:** `claim-xxxxxxx` from [plex.tv/claim](https://plex.tv/claim) (valid 4 minutes)

**Tip:** Leave empty if you want to configure Plex manually later

---

### Screen 6: Storage Configuration

```
┌────────── Storage Configuration ──────────────┐
│                                               │
│  Do you want to mount NFS storage from a NAS? │
│                                               │
│  Recommended for large media libraries.       │
│                                               │
│              < Yes >    < No >                │
└───────────────────────────────────────────────┘
```

**Select:**
- **Yes** if you have a NAS (TrueNAS, Synology, etc.)
- **No** to use local storage (limited by LXC container size)

---

### Screen 7a: NAS IP (if Yes)

```
┌────────── NAS IP Address ─────────────────────┐
│                                               │
│  Enter your NAS IP address:                   │
│                                               │
│  10.0.0.8_________________________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

### Screen 7b: NFS Media Path

```
┌────────── NFS Media Path ─────────────────────┐
│                                               │
│  Enter NFS export path for media library:     │
│                                               │
│  (e.g., /mnt/tank0/media)                     │
│                                               │
│  /mnt/tank0/media_________________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

### Screen 7c: NFS Downloads Path

```
┌────────── NFS Downloads Path ─────────────────┐
│                                               │
│  Enter NFS export path for downloads:         │
│                                               │
│  (e.g., /mnt/tank0/downloads)                 │
│                                               │
│  /mnt/tank0/downloads_____________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

---

### Screen 8: Service Selection

```
┌────────── Select services to install: ────────┐
│                                               │
│  [X] sonarr       TV show automation          │
│  [X] radarr       Movie automation            │
│  [X] prowlarr     Indexer manager             │
│  [X] bazarr       Subtitle automation         │
│  [ ] lidarr       Music automation        ←─  │
│  [X] sabnzbd      Usenet downloader           │
│  [X] qbittorrent  Torrent client              │
│  [X] seerr       Media requests (modern Overseerr)              │
│  [X] tautulli     Plex monitoring             │
│  [X] dozzle       Log viewer                  │
│  [ ] ombi        Media requests (alternative)                   │
│  [ ] notifiarr   Discord notifications (advanced)│
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**How to use:**
- **Arrow keys** to navigate
- **Space** to toggle checkboxes
- **Enter** to confirm

**Default:** Everything checked except Lidarr

---

### Screen 9: Service Configuration

```
┌────────── Service Configuration ──────────────┐
│                                               │
│  Now let's configure your selected services.  │
│                                               │
│  You can customize settings or use defaults.  │
│                                               │
│              < OK >                            │
└───────────────────────────────────────────────┘
```

Then **for each selected service**, you'll get specific prompts:

---

#### 9a: Sonarr Quality

```
┌────────── Sonarr: Default Quality Profile ────┐
│                                               │
│  any     Any quality (recommended for testing)│
│  1080p   1080p HDTV/WEB-DL                    │
│  720p    720p HDTV/WEB-DL                     │
│  4k      4K UHD (requires fast transcoding)   │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

#### 9b: Sonarr Root Folder

```
┌────────── Sonarr: TV Shows Root Folder ───────┐
│                                               │
│  (Path inside container where TV shows        │
│   will be stored)                             │
│                                               │
│  /media/tv________________________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**Default:** `/media/tv` (recommended)

---

#### 9c: Radarr Quality

```
┌────────── Radarr: Default Quality Profile ────┐
│                                               │
│  any     Any quality (recommended for testing)│
│  1080p   1080p Bluray/WEB-DL                  │
│  720p    720p Bluray/WEB-DL                   │
│  4k      4K UHD (requires fast transcoding)   │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

#### 9d: Radarr Root Folder

```
┌────────── Radarr: Movies Root Folder ─────────┐
│                                               │
│  (Path inside container where movies          │
│   will be stored)                             │
│                                               │
│  /media/movies____________________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

---

#### 9e: Prowlarr Sync

```
┌────────── Prowlarr: Auto-sync to Sonarr/Radarr? ┐
│                                               │
│  full      Full sync (recommended - auto-add  │
│            indexers)                          │
│  manual    Manual only (configure indexers    │
│            yourself)                          │
│  disabled  Disabled (standalone mode)         │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**Recommended:** `full` (auto-sync)

---

#### 9f: Bazarr Languages

```
┌────────── Bazarr: Preferred Subtitle Languages ┐
│                                               │
│  (Comma-separated, e.g., en,es,fr)            │
│                                               │
│  en_______________________________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**Examples:**
- `en` — English only
- `en,es` — English + Spanish
- `en,es,fr,de` — Multiple languages

---

#### 9g: qBittorrent Port

```
┌────────── qBittorrent: Web UI Port ───────────┐
│                                               │
│  (Default: 8080)                              │
│                                               │
│  8080_____________________________________    │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

#### 9h: qBittorrent VPN

```
┌────────── qBittorrent: Enable VPN? ───────────┐
│                                               │
│  (Routes torrent traffic through VPN          │
│   container - requires OpenVPN config)        │
│                                               │
│              < Yes >    < No >                │
└───────────────────────────────────────────────┘
```

If **Yes**, you'll see:

```
┌────────── VPN Configuration ──────────────────┐
│                                               │
│  You'll need to provide your OpenVPN config   │
│  after install:                               │
│                                               │
│  1. Place .ovpn file in                       │
│     /opt/docker/qbittorrent/config/           │
│  2. Restart container:                        │
│     docker restart qbittorrent                │
│                                               │
│  Popular VPN providers:                       │
│  • Mullvad                                    │
│  • ProtonVPN                                  │
│  • NordVPN                                    │
│                                               │
│              < OK >                            │
└───────────────────────────────────────────────┘
```

---

#### 9i: Seerr Permissions

```
┌────────── Seerr: Default User Permissions ─┐
│                                               │
│  admin      Admin (full control)              │
│  user       User (request + manage own)       │
│  requestor  Requestor (request only)          │
│  none       None (manual approval required)   │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**Recommended:** `user` (balanced)

---

### Screen 10: GPU Transcoding

```
┌────────── Hardware Transcoding ───────────────┐
│                                               │
│  none    CPU transcoding only                 │
│  intel   Intel QuickSync (/dev/dri)           │
│  nvidia  NVIDIA GPU                           │
│                                               │
│              < OK >    < Cancel >             │
└───────────────────────────────────────────────┘
```

**Select:**
- **intel** if you have Intel CPU with QuickSync (most common)
- **nvidia** if you have NVIDIA GPU passed through
- **none** if unsure (works everywhere, just slower)

---

### Screen 11: Configuration Summary

```
┌────────── Configuration Summary ──────────────┐
│                                               │
│  Domain: yourdomain.com                      │
│  Cloudflare Tunnel: yes                       │
│  Storage: NFS (10.0.0.8)                      │
│                                               │
│  Services:                                    │
│    • sonarr                                   │
│    • radarr                                   │
│    • prowlarr                                 │
│    • bazarr                                   │
│    • sabnzbd                                  │
│    • qbittorrent                              │
│    • seerr                                │
│    • tautulli                                 │
│    • dozzle                                   │
│                                               │
│  GPU: intel                                   │
│                                               │
│  Sonarr: 1080p → /media/tv                    │
│  Radarr: 1080p → /media/movies                │
│  Bazarr: Languages: en,es                     │
│  qBittorrent: Port 8080, VPN: yes             │
│                                               │
│              < OK >                            │
└───────────────────────────────────────────────┘
```

**Review everything** — this is your last chance to verify!

---

### Screen 12: Final Confirmation

```
┌────────── Ready to Install ───────────────────┐
│                                               │
│  Configuration complete!                      │
│                                               │
│  Proceed with installation?                   │
│                                               │
│  (This will take 5-10 minutes)                │
│                                               │
│              < Yes >    < No >                │
└───────────────────────────────────────────────┘
```

**Select Yes** to start the automated installation.

---

## Installation Progress

After confirmation, you'll see real-time logs:

```
[2026-03-18 09:30:00] ✓ Prerequisites met
[2026-03-18 09:30:05] Installing base packages...
[2026-03-18 09:30:30] ✓ Base packages installed
[2026-03-18 09:30:31] Installing Docker...
[2026-03-18 09:31:45] ✓ Docker installed
[2026-03-18 09:31:46] Configuring UFW firewall...
[2026-03-18 09:31:50] ✓ Firewall configured (SSH only)
[2026-03-18 09:31:51] Configuring NFS mounts...
[2026-03-18 09:32:00] ✓ NFS mounts configured
[2026-03-18 09:32:01] Creating Docker network...
[2026-03-18 09:32:02] ✓ Created 'proxy' network
[2026-03-18 09:32:03] ✓ Environment file created
[2026-03-18 09:32:04] Deploying Traefik...
[2026-03-18 09:32:05] ✓ Traefik configured
[2026-03-18 09:32:06] Generating docker-compose.yml...
[2026-03-18 09:32:07] ✓ docker-compose.yml generated
[2026-03-18 09:32:08] Starting Docker stack...
[2026-03-18 09:35:30] ✓ Stack started
[2026-03-18 09:35:31] Installation complete!
```

---

## Success Screen

```
╔════════════════════════════════════════╗
║   Media Stack Installation Complete   ║
╚════════════════════════════════════════╝

Services accessible at:

  • Plex:      https://plex.yourdomain.com
  • Portainer: https://portainer.yourdomain.com
  • Sonarr:    https://sonarr.yourdomain.com
  • Radarr:    https://radarr.yourdomain.com
  • Prowlarr:  https://prowlarr.yourdomain.com
  • Seerr:     https://seerr.yourdomain.com

Next steps:
  1. Configure Plex libraries at plex.yourdomain.com
  2. Add indexers in Prowlarr
  3. Connect apps in Prowlarr → Sonarr/Radarr

Logs: /var/log/mediastack-install.log
Config: /opt/docker
```

---

## That's It!

The entire setup is **guided and interactive**. You just answer questions, and the installer does everything else automatically.

**Total time:** 5-10 minutes from start to working media server! 🚀
