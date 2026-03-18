# CHANGELOG

All notable changes to the media-stack-lxc project.

---

## [Unreleased]

### Added
- **Ombi** - Alternative media request platform (optional service)
- **Notifiarr** - Discord notifications for media stack events (advanced, optional)
- **Seerr** - Modern Overseerr fork for media requests (default enabled)
- **CNAME Guide** - Beginner-friendly DNS and routing explanation
- **Cloudflare Setup Guide** - Complete walkthrough for Cloudflare Tunnel + Traefik certificates
- **Service defaults** - All services pre-configured with sensible defaults (1080p quality, proper paths)
- **Configuration summary** - Review all settings before installation

### Changed
- Replaced Overseerr with Seerr as default media request service
- Removed Heimdall dashboard (simplified service list)
- Wizard now uses smart defaults instead of per-service configuration prompts
- Documentation uses generic `yourdomain.com` instead of personal examples
- All docs reviewed for beginner/intermediate sysadmin clarity

### Documentation
- `docs/CLOUDFLARE_SETUP.md` - Why Cloudflare, complete setup flow, troubleshooting
- `docs/CNAME_GUIDE.md` - Real-world analogies, step-by-step DNS setup, Traefik routing explained
- `docs/QUICK_START.md` - Updated with Seerr, Ombi, and Notifiarr
- `docs/WIZARD_WALKTHROUGH.md` - Visual guide through entire installer
- `README.md` - Comprehensive overview with links to all guides

---

## [Initial Release] - 2026-03-18

### Core Features
- **One-command installer** with interactive TUI wizard (dialog-based)
- **Docker Compose** orchestration for all services
- **Cloudflare Tunnel** integration for secure external access (no port forwarding)
- **Traefik** reverse proxy with automatic Let's Encrypt SSL certificates
- **Hardware transcoding** support (Intel QuickSync, NVIDIA GPU)
- **NFS auto-mount** for NAS storage integration
- **UFW firewall** configuration (SSH-only by default)

### Services Included
- **Media Server:** Plex
- **Automation:** Sonarr, Radarr, Prowlarr, Bazarr, Lidarr (optional)
- **Download Clients:** SABnzbd, qBittorrent
- **Management:** Portainer, Dozzle
- **Monitoring:** Tautulli
- **Requests:** Seerr (default), Ombi (optional)
- **Notifications:** Notifiarr (optional, advanced)

### Architecture
- Based on production-tested **cpdock1** media server design
- All services on isolated `proxy` Docker network
- Automatic HTTPS via Traefik + Let's Encrypt DNS-01 challenge
- Cloudflare Tunnel for zero-exposed-ports security

### Installation
- Debian 12 / Ubuntu 22.04+ LXC container
- Proxmox VE deployment
- Minimum: 2 CPU, 4 GB RAM, 30 GB disk
- Recommended: 4 CPU, 8 GB RAM, 50 GB SSD + NFS storage

---

## Future Plans

- Complete docker-compose templates for all services
- GPU passthrough automation (Intel /dev/dri, NVIDIA device mapping)
- Authentik SSO integration (optional)
- Backup/restore scripts
- Update automation
- GitHub Actions CI/CD
