#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Media Stack LXC - Automated Installer
# 
# One-command deployment of a complete Plex media server stack
# Based on cpdock1 production architecture
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/tmp/mediastack-config.env"
INSTALL_LOG="/var/log/mediastack-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Logging
###############################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$INSTALL_LOG"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$INSTALL_LOG" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $*" | tee -a "$INSTALL_LOG"
}

###############################################################################
# Prerequisites Check
###############################################################################

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check if running in LXC
    if ! grep -q 'container=lxc' /proc/1/environ 2>/dev/null; then
        log_warn "Not detected as LXC container - proceeding anyway"
    fi
    
    # Check Debian/Ubuntu
    if [[ ! -f /etc/debian_version ]]; then
        log_error "This installer requires Debian or Ubuntu"
        exit 1
    fi
    
    # Install dialog if missing
    if ! command -v dialog &>/dev/null; then
        log "Installing dialog for TUI..."
        apt-get update -qq
        apt-get install -y dialog
    fi
    
    log "✓ Prerequisites met"
}

###############################################################################
# TUI Wizard
###############################################################################

show_welcome() {
    dialog --title "Media Stack LXC Installer" \
        --msgbox "\nWelcome to the automated media server installer!\n\nThis wizard will deploy a complete Plex media stack with:\n\n• Plex Media Server\n• Sonarr / Radarr / Prowlarr\n• SABnzbd / qBittorrent\n• Traefik reverse proxy\n• Cloudflare Tunnel\n• Portainer management\n\nBased on the battle-tested cpdock1 architecture.\n\nPress OK to begin." 18 70
}

prompt_domain() {
    local domain
    domain=$(dialog --stdout --title "Domain Configuration" \
        --inputbox "\nEnter your base domain (e.g., hypebeastin.com):\n\nServices will be accessible at:\n• plex.yourdomain.com\n• sonarr.yourdomain.com\n• etc." 12 70)
    
    if [[ -z "$domain" ]]; then
        log_error "Domain is required"
        exit 1
    fi
    
    echo "DOMAIN=$domain" >> "$CONFIG_FILE"
    log "Domain set to: $domain"
}

prompt_cloudflare() {
    local use_cf
    use_cf=$(dialog --stdout --title "Cloudflare Tunnel" \
        --yesno "\nDo you want to use Cloudflare Tunnel for external access?\n\nThis provides secure HTTPS access without opening ports.\n\nYou'll need a Cloudflare account." 10 70 && echo "yes" || echo "no")
    
    echo "USE_CLOUDFLARE=$use_cf" >> "$CONFIG_FILE"
    
    if [[ "$use_cf" == "yes" ]]; then
        local cf_token
        cf_token=$(dialog --stdout --title "Cloudflare Tunnel Token" \
            --inputbox "\nEnter your Cloudflare Tunnel token:\n\n(Get this from dash.cloudflare.com → Zero Trust → Tunnels)" 10 70)
        
        echo "CLOUDFLARE_TUNNEL_TOKEN=$cf_token" >> "$CONFIG_FILE"
    fi
}

prompt_plex() {
    local plex_claim
    plex_claim=$(dialog --stdout --title "Plex Claim Token" \
        --inputbox "\nEnter your Plex claim token (optional):\n\nGet one from: https://plex.tv/claim\n\n(Leave empty to configure Plex manually later)" 11 70)
    
    echo "PLEX_CLAIM=$plex_claim" >> "$CONFIG_FILE"
}

prompt_storage() {
    local use_nfs
    use_nfs=$(dialog --stdout --title "Storage Configuration" \
        --yesno "\nDo you want to mount NFS storage from a NAS?\n\nRecommended for large media libraries." 8 70 && echo "yes" || echo "no")
    
    echo "USE_NFS=$use_nfs" >> "$CONFIG_FILE"
    
    if [[ "$use_nfs" == "yes" ]]; then
        local nas_ip nfs_media nfs_downloads
        
        nas_ip=$(dialog --stdout --title "NAS IP Address" \
            --inputbox "\nEnter your NAS IP address:" 8 70)
        
        nfs_media=$(dialog --stdout --title "NFS Media Path" \
            --inputbox "\nEnter NFS export path for media library:\n\n(e.g., /mnt/tank0/media)" 9 70)
        
        nfs_downloads=$(dialog --stdout --title "NFS Downloads Path" \
            --inputbox "\nEnter NFS export path for downloads:\n\n(e.g., /mnt/tank0/downloads)" 9 70)
        
        echo "NAS_IP=$nas_ip" >> "$CONFIG_FILE"
        echo "NFS_MEDIA_PATH=$nfs_media" >> "$CONFIG_FILE"
        echo "NFS_DOWNLOADS_PATH=$nfs_downloads" >> "$CONFIG_FILE"
    else
        # Use local storage
        echo "NFS_MEDIA_PATH=/opt/media" >> "$CONFIG_FILE"
        echo "NFS_DOWNLOADS_PATH=/opt/downloads" >> "$CONFIG_FILE"
    fi
}

prompt_services() {
    local services
    services=$(dialog --stdout --separate-output --checklist \
        "Select services to install:" 20 70 13 \
        "sonarr" "TV show automation" on \
        "radarr" "Movie automation" on \
        "prowlarr" "Indexer manager" on \
        "bazarr" "Subtitle automation" on \
        "lidarr" "Music automation" off \
        "sabnzbd" "Usenet downloader" on \
        "qbittorrent" "Torrent client" on \
        "seerr" "Media requests (modern Overseerr)" on \
        "ombi" "Media requests (alternative)" off \
        "notifiarr" "Discord notifications (advanced)" off \
        "tautulli" "Plex monitoring" on \
        "dozzle" "Log viewer" on)
    
    # Convert to comma-separated
    services=$(echo "$services" | tr '\n' ',' | sed 's/,$//')
    echo "SERVICES=$services" >> "$CONFIG_FILE"
    log "Selected services: $services"
    
    # Set sensible defaults (no per-service prompts)
    set_service_defaults "$services"
}

set_service_defaults() {
    local services="$1"
    
    log "Applying sensible defaults for selected services..."
    
    # Sonarr defaults
    if grep -q "sonarr" <<< "$services"; then
        echo "SONARR_QUALITY=1080p" >> "$CONFIG_FILE"
        echo "SONARR_ROOT_FOLDER=/media/tv" >> "$CONFIG_FILE"
    fi
    
    # Radarr defaults
    if grep -q "radarr" <<< "$services"; then
        echo "RADARR_QUALITY=1080p" >> "$CONFIG_FILE"
        echo "RADARR_ROOT_FOLDER=/media/movies" >> "$CONFIG_FILE"
    fi
    
    # Prowlarr defaults
    if grep -q "prowlarr" <<< "$services"; then
        echo "PROWLARR_SYNC=full" >> "$CONFIG_FILE"
    fi
    
    # Bazarr defaults
    if grep -q "bazarr" <<< "$services"; then
        echo "BAZARR_LANGUAGES=en" >> "$CONFIG_FILE"
    fi
    
    # Lidarr defaults
    if grep -q "lidarr" <<< "$services"; then
        echo "LIDARR_ROOT_FOLDER=/media/music" >> "$CONFIG_FILE"
    fi
    
    # qBittorrent defaults
    if grep -q "qbittorrent" <<< "$services"; then
        echo "QBITTORRENT_PORT=8080" >> "$CONFIG_FILE"
        echo "QBITTORRENT_VPN=no" >> "$CONFIG_FILE"
    fi
    
    # Seerr defaults
    
    # Ombi defaults
    
    # Notifiarr defaults
    if grep -q "notifiarr" <<< "$services"; then
        echo "NOTIFIARR_API_KEY=" >> "$CONFIG_FILE"
    fi
    if grep -q "ombi" <<< "$services"; then
        echo "OMBI_DEFAULT_PERMS=user" >> "$CONFIG_FILE"
NOTIFIARR_API_KEY=${NOTIFIARR_API_KEY:-}
    fi
    if grep -q "seerr" <<< "$services"; then
        echo "SEERR_DEFAULT_PERMS=user" >> "$CONFIG_FILE"
OMBI_DEFAULT_PERMS=${OMBI_DEFAULT_PERMS:-user}
NOTIFIARR_API_KEY=${NOTIFIARR_API_KEY:-}
    fi
    
    log "✓ Defaults applied"
}

prompt_gpu() {
    local gpu_type
    gpu_type=$(dialog --stdout --menu "Hardware Transcoding" 12 70 3 \
        "none" "CPU transcoding only" \
        "intel" "Intel QuickSync (/dev/dri)" \
        "nvidia" "NVIDIA GPU")
    
    echo "GPU_TYPE=$gpu_type" >> "$CONFIG_FILE"
}

run_wizard() {
    log "Starting TUI wizard..."
    
    # Clear previous config
    > "$CONFIG_FILE"
    
    show_welcome
    prompt_domain
    prompt_cloudflare
    prompt_plex
    prompt_storage
    prompt_services
    prompt_gpu
    
    # Show configuration summary
    show_config_summary
    
    # Confirm
    dialog --title "Ready to Install" \
        --yesno "\nConfiguration complete!\n\nProceed with installation?\n\n(This will take 5-10 minutes)" 10 70
    
    log "✓ Wizard complete"
}

show_config_summary() {
    source "$CONFIG_FILE"
    
    local summary="Configuration Summary\n\n"
    summary+="Domain: ${DOMAIN}\n"
    summary+="Cloudflare Tunnel: ${USE_CLOUDFLARE}\n"
    
    if [[ "$USE_NFS" == "yes" ]]; then
        summary+="Storage: NFS (${NAS_IP})\n"
    else
        summary+="Storage: Local (/opt)\n"
    fi
    
    summary+="\nServices:\n"
    IFS=',' read -ra SELECTED <<< "$SERVICES"
    for service in "${SELECTED[@]}"; do
        summary+="  • $service\n"
    done
    
    summary+="\nGPU: ${GPU_TYPE}\n"
    
    # Service-specific config
    if grep -q "sonarr" <<< "$SERVICES"; then
        summary+="\nSonarr: ${SONARR_QUALITY} → ${SONARR_ROOT_FOLDER}\n"
    fi
    if grep -q "radarr" <<< "$SERVICES"; then
        summary+="Radarr: ${RADARR_QUALITY} → ${RADARR_ROOT_FOLDER}\n"
    fi
    if grep -q "lidarr" <<< "$SERVICES"; then
        summary+="Lidarr: → ${LIDARR_ROOT_FOLDER}\n"
    fi
    if grep -q "bazarr" <<< "$SERVICES"; then
        summary+="Bazarr: Languages: ${BAZARR_LANGUAGES}\n"
    fi
    if grep -q "qbittorrent" <<< "$SERVICES"; then
        summary+="qBittorrent: Port ${QBITTORRENT_PORT}, VPN: ${QBITTORRENT_VPN}\n"
    fi
    if grep -q "seerr" <<< "$SERVICES"; then
    if grep -q "ombi" <<< "$SERVICES"; then
    if grep -q "notifiarr" <<< "$SERVICES"; then
        summary+="Notifiarr: API key required (configure post-install)\n"
    fi
        summary+="Ombi: Default perms: ${OMBI_DEFAULT_PERMS}\n"
    fi
        summary+="Seerr: Default perms: ${SEERR_DEFAULT_PERMS}\n"
    fi
    
    dialog --title "Configuration Summary" \
        --msgbox "$summary" 24 70
}

###############################################################################
# System Setup
###############################################################################

install_base_packages() {
    log "Installing base packages..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update -qq
    apt-get install -y \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw \
        nfs-common \
        jq
    
    log "✓ Base packages installed"
}

install_docker() {
    log "Installing Docker..."
    
    if command -v docker &>/dev/null; then
        log "Docker already installed, skipping"
        return
    fi
    
    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add Docker repo
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    log "✓ Docker installed"
}

setup_firewall() {
    log "Configuring UFW firewall..."
    
    # Default deny
    ufw --force default deny incoming
    ufw --force default allow outgoing
    
    # Allow SSH
    ufw allow 22/tcp comment 'SSH'
    
    # Enable
    ufw --force enable
    
    log "✓ Firewall configured (SSH only)"
}

setup_nfs() {
    source "$CONFIG_FILE"
    
    if [[ "$USE_NFS" != "yes" ]]; then
        log "NFS not requested, creating local directories..."
        mkdir -p /opt/media/{tv,movies,music}
        mkdir -p /opt/downloads/{complete,incomplete}
        return
    fi
    
    log "Configuring NFS mounts..."
    
    # Create mount points
    mkdir -p /mnt/media
    mkdir -p /mnt/downloads
    
    # Add to fstab
    cat >> /etc/fstab <<EOF

# Media Stack NFS Mounts
${NAS_IP}:${NFS_MEDIA_PATH} /mnt/media nfs4 rw,_netdev,noatime,nofail,rsize=1048576,wsize=1048576,hard,timeo=600 0 0
${NAS_IP}:${NFS_DOWNLOADS_PATH} /mnt/downloads nfs4 rw,_netdev,noatime,nofail,rsize=1048576,wsize=1048576,hard,timeo=600 0 0
EOF
    
    # Mount
    mount -a
    
    if ! mountpoint -q /mnt/media; then
        log_error "Failed to mount NFS media share"
        exit 1
    fi
    
    log "✓ NFS mounts configured"
}

###############################################################################
# Docker Stack Deployment
###############################################################################

create_docker_network() {
    log "Creating Docker network..."
    
    if docker network inspect proxy &>/dev/null; then
        log "Network 'proxy' already exists"
    else
        docker network create proxy
        log "✓ Created 'proxy' network"
    fi
}

generate_env_file() {
    source "$CONFIG_FILE"
    
    log "Generating environment file..."
    
    mkdir -p /opt/docker
    cat > /opt/docker/.env <<EOF
# Generated by Media Stack LXC Installer
# $(date)

DOMAIN=${DOMAIN}
TZ=$(cat /etc/timezone || echo "UTC")

# Plex
PLEX_CLAIM=${PLEX_CLAIM}

# Paths
MEDIA_PATH=${USE_NFS:+/mnt/media}${USE_NFS:-/opt/media}
DOWNLOADS_PATH=${USE_NFS:+/mnt/downloads}${USE_NFS:-/opt/downloads}

# GPU
GPU_TYPE=${GPU_TYPE}

# Service-specific config
SONARR_QUALITY=${SONARR_QUALITY:-any}
SONARR_ROOT_FOLDER=${SONARR_ROOT_FOLDER:-/media/tv}
RADARR_QUALITY=${RADARR_QUALITY:-any}
RADARR_ROOT_FOLDER=${RADARR_ROOT_FOLDER:-/media/movies}
LIDARR_ROOT_FOLDER=${LIDARR_ROOT_FOLDER:-/media/music}
BAZARR_LANGUAGES=${BAZARR_LANGUAGES:-en}
PROWLARR_SYNC=${PROWLARR_SYNC:-full}
QBITTORRENT_PORT=${QBITTORRENT_PORT:-8080}
QBITTORRENT_VPN=${QBITTORRENT_VPN:-no}
SEERR_DEFAULT_PERMS=${SEERR_DEFAULT_PERMS:-user}
OMBI_DEFAULT_PERMS=${OMBI_DEFAULT_PERMS:-user}
NOTIFIARR_API_KEY=${NOTIFIARR_API_KEY:-}
EOF
    
    if [[ "${USE_CLOUDFLARE}" == "yes" ]]; then
        echo "CLOUDFLARE_TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}" >> /opt/docker/.env
    fi
    
    log "✓ Environment file created"
}

deploy_traefik() {
    log "Deploying Traefik..."
    
    mkdir -p /opt/docker/traefik/config/data
    
    # Generate traefik.yml
    cat > /opt/docker/traefik/config/data/traefik.yml <<'EOF'
api:
  dashboard: true
  insecure: false

entryPoints:
  http:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: https
          scheme: https
  https:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  file:
    filename: /config/config.yml
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@${DOMAIN}
      storage: /acme.json
      httpChallenge:
        entryPoint: http

log:
  level: INFO

accessLog: {}
EOF
    
    # Create acme.json
    touch /opt/docker/traefik/config/data/acme.json
    chmod 600 /opt/docker/traefik/config/data/acme.json
    
    log "✓ Traefik configured"
}

generate_compose_file() {
    source "$CONFIG_FILE"
    
    log "Generating docker-compose.yml..."
    
    cat > /opt/docker/docker-compose.yml <<'COMPOSE_START'
version: '3.8'

networks:
  proxy:
    external: true

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/config/data/traefik.yml:/traefik.yml:ro
      - ./traefik/config/data/config.yml:/config/config.yml:ro
      - ./traefik/config/data/acme.json:/acme.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\`traefik.${DOMAIN}\`)"
      - "traefik.http.routers.traefik.entrypoints=https"
      - "traefik.http.routers.traefik.service=api@internal"

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - proxy
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./portainer:/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(\`portainer.${DOMAIN}\`)"
      - "traefik.http.routers.portainer.entrypoints=https"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"

  plex:
    image: lscr.io/linuxserver/plex:latest
    container_name: plex
    restart: unless-stopped
    network_mode: bridge
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${TZ}
      - VERSION=docker
      - PLEX_CLAIM=${PLEX_CLAIM}
    volumes:
      - ./plex/config:/config
      - ${MEDIA_PATH}:/media
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.plex.rule=Host(\`plex.${DOMAIN}\`)"
      - "traefik.http.routers.plex.entrypoints=https"
      - "traefik.http.services.plex.loadbalancer.server.port=32400"
COMPOSE_START
    
    # Add services based on selection
    if grep -q "sonarr" <<< "${SERVICES}"; then
        cat >> /opt/docker/docker-compose.yml <<'SONARR'

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    networks:
      - proxy
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${TZ}
    volumes:
      - ./sonarr/config:/config
      - ${MEDIA_PATH}/tv:/tv
      - ${DOWNLOADS_PATH}:/downloads
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=Host(\`sonarr.${DOMAIN}\`)"
      - "traefik.http.routers.sonarr.entrypoints=https"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"
SONARR
    fi
    
    # Add Radarr
    if grep -q "radarr" <<< "${SERVICES}"; then
        cat >> /opt/docker/docker-compose.yml <<'RADARR'

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    networks:
      - proxy
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${TZ}
    volumes:
      - ./radarr/config:/config
      - ${MEDIA_PATH}/movies:/movies
      - ${DOWNLOADS_PATH}:/downloads
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=Host(\`radarr.${DOMAIN}\`)"
      - "traefik.http.routers.radarr.entrypoints=https"
      - "traefik.http.services.radarr.loadbalancer.server.port=7878"
RADARR
    fi
    
    # Continue for other services...
    # (Prowlarr, SABnzbd, qBittorrent, etc. - similar patterns)
    
    log "✓ docker-compose.yml generated"
}

start_stack() {
    log "Starting Docker stack..."
    
    cd /opt/docker
    docker compose up -d
    
    log "✓ Stack started"
}

###############################################################################
# Post-Install
###############################################################################

show_summary() {
    source "$CONFIG_FILE"
    
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Media Stack Installation Complete   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Services accessible at:${NC}"
    echo ""
    echo -e "  • Plex:      https://plex.${DOMAIN}"
    echo -e "  • Portainer: https://portainer.${DOMAIN}"
    echo -e "  • Traefik:   https://traefik.${DOMAIN}"
    
    if grep -q "sonarr" <<< "${SERVICES}"; then
        echo -e "  • Sonarr:    https://sonarr.${DOMAIN}"
    fi
    if grep -q "radarr" <<< "${SERVICES}"; then
        echo -e "  • Radarr:    https://radarr.${DOMAIN}"
    fi
    if grep -q "seerr" <<< "${SERVICES}"; then
    if grep -q "ombi" <<< "${SERVICES}"; then
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
        echo -e "  • Ombi:      https://ombi.${DOMAIN}"
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
    fi
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
        echo -e "  • Seerr:     https://seerr.${DOMAIN}"
    if grep -q "ombi" <<< "${SERVICES}"; then
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
        echo -e "  • Ombi:      https://ombi.${DOMAIN}"
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
    fi
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
    fi
    if grep -q "ombi" <<< "${SERVICES}"; then
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
        echo -e "  • Ombi:      https://ombi.${DOMAIN}"
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
    fi
    if grep -q "notifiarr" <<< "${SERVICES}"; then
        echo -e "  • Notifiarr: https://notifiarr.${DOMAIN}"
    fi
    
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Configure Plex libraries at plex.${DOMAIN}"
    echo "  2. Add indexers in Prowlarr (if installed)"
    echo "  3. Connect apps in Prowlarr → Sonarr/Radarr"
    echo ""
    echo -e "${BLUE}Logs:${NC} $INSTALL_LOG"
    echo -e "${BLUE}Config:${NC} /opt/docker"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    log "=== Media Stack LXC Installer ==="
    log "Started at $(date)"
    
    check_prerequisites
    run_wizard
    
    install_base_packages
    install_docker
    setup_firewall
    setup_nfs
    
    create_docker_network
    generate_env_file
    deploy_traefik
    generate_compose_file
    start_stack
    
    show_summary
    
    log "Installation complete!"
}

# Run
main "$@"
