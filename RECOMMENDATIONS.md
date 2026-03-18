## Media Stack LXC - Project Review

---

### 1. Architecture Soundness: 7/10

The Cloudflare Tunnel → Traefik → Docker architecture is solid and production-proven. Good choices:
- Zero-open-ports via Cloudflare Tunnel
- Traefik for automated TLS and routing
- LinuxServer.io images (well-maintained)
- `set -euo pipefail` at script top

**Issues:**

**Plex uses `network_mode: bridge` but also Traefik labels** (line 592-606 of install.sh). This is contradictory — Plex won't be on the `proxy` network, so Traefik can't route to it via Docker provider:

```yaml
  plex:
    network_mode: bridge    # ← NOT on 'proxy' network
    labels:
      - "traefik.enable=true"  # ← Traefik can't reach this container
```

Fix: Either put Plex on the `proxy` network like everything else, or use Traefik's file provider to route to Plex's host-mapped port.

**No `cloudflared` service in the compose file.** The wizard collects the tunnel token, the env file stores it, but `generate_compose_file()` never adds a `cloudflared` container. The architecture diagram promises it but the code doesn't deliver.

**ACME challenge mismatch.** The docs describe DNS-01 challenge with Cloudflare API token, but `traefik.yml` (line 518) configures `httpChallenge`. If using Cloudflare Tunnel (no open ports), HTTP-01 will fail:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      httpChallenge:        # ← Will fail behind Cloudflare Tunnel
        entryPoint: http
```

Should be:
```yaml
      dnsChallenge:
        provider: cloudflare
```

---

### 2. Documentation Completeness: 8/10

The docs are genuinely excellent for beginners. The CNAME guide with real-world analogies, visual diagrams, and step-by-step troubleshooting is above average. Specific strengths:
- Traffic flow diagrams with ASCII art
- "Debug order" checklist in CNAME_GUIDE.md
- Honest "what you should still do" security section

**Issues:**

**README references files that don't exist.** The file structure diagram (line 134-157) lists `lib/tui.sh`, `lib/docker.sh`, `lib/network.sh`, `lib/services.sh`, `templates/`, `docs/DEPLOYMENT.md`, `docs/TROUBLESHOOTING.md`, `docs/ARCHITECTURE.md` — none of these exist. Everything is monolithic in `install.sh`.

**Inconsistent domain in docs.** The input box example still shows `hypebeastin.com` at install.sh:84 despite the CHANGELOG noting this was replaced with generic domains.

**Broken link in CNAME_GUIDE.md line 330:** `github.com/hyped-up/media-stack-lxc` — same in CLOUDFLARE_SETUP.md line 187. These appear to be placeholder repo URLs.

**No QUICK_START.md or WIZARD_WALKTHROUGH.md** exist despite being linked from README line 69-72.

---

### 3. Critical Missing Pieces

**The compose file is incomplete.** `generate_compose_file()` only generates Traefik, Portainer, Plex, Sonarr, and Radarr. Lines 661-663 say `# Continue for other services... (Prowlarr, SABnzbd, qBittorrent, etc. - similar patterns)`. That's ~60% of the advertised services missing.

**No Traefik `config.yml` file provider.** Traefik static config references `file: filename: /config/config.yml` (line 510-511) but this file is never created. Traefik will fail to start or log errors.

**No TLS router configuration.** None of the Traefik labels include `tls: true` or a certificate resolver:
```yaml
# Missing from every service:
- "traefik.http.routers.sonarr.tls=true"
- "traefik.http.routers.sonarr.tls.certresolver=letsencrypt"
```

Without these, HTTPS won't work even if the ACME challenge is fixed.

**No GPU passthrough in compose.** The wizard collects `GPU_TYPE` but `generate_compose_file()` never adds device mappings. No `/dev/dri` mount for Intel, no NVIDIA runtime.

**`backup.sh` referenced but doesn't exist** (README line 279).

---

### 4. Security Gaps

**Sensitive tokens stored in plaintext** at `/tmp/mediastack-config.env` (line 12) — world-readable by default. The Cloudflare tunnel token and Plex claim token sit in `/tmp` during installation. Should be `600` permissions:
```bash
CONFIG_FILE="/tmp/mediastack-config.env"
# Missing: umask 077 or chmod 600 "$CONFIG_FILE"
```

**Traefik dashboard exposed without authentication** (line 566-568). Anyone with the URL `traefik.yourdomain.com` can view your routing infrastructure. Needs BasicAuth or ForwardAuth middleware:
```yaml
# Currently: no auth at all
- "traefik.http.routers.traefik.rule=Host(`traefik.${DOMAIN}`)"
```

**Portainer exposed without Traefik auth middleware.** Portainer has its own auth, but it's a high-value target — consider IP whitelisting or additional middleware.

**No `no-new-privileges` on Plex container** (unlike Traefik and Portainer which have it).

**Docker socket mounted read-only in Traefik (good), but Portainer has full R/W access** to the Docker socket — expected but worth documenting the risk.

**The `.env` file at `/opt/docker/.env` has no restricted permissions set.** Contains tunnel tokens and secrets.

**No Cloudflare API token collected by wizard** despite docs saying it will be (CLOUDFLARE_SETUP.md line 97). The wizard only asks for the tunnel token, not the DNS API token needed for cert challenges.

---

### 5. UX Problems

**Severely broken `show_summary()` function.** Lines 700-738 have catastrophically misindented/nested if-statements that will produce duplicate Notifiarr entries (up to 8 times!) and incorrectly nest Seerr/Ombi output inside each other. This is clearly a merge/edit artifact:

```bash
# Line 700-726: Seerr check wraps Ombi check wraps Notifiarr check,
# then Ombi duplicates with Notifiarr, then Notifiarr standalone...
# Result: "Notifiarr" could print 5+ times
```

**Same bug in `set_service_defaults()`** — lines 220-228 have orphaned variable expansions outside any echo/heredoc:
```bash
    if grep -q "ombi" <<< "$services"; then
        echo "OMBI_DEFAULT_PERMS=user" >> "$CONFIG_FILE"
NOTIFIARR_API_KEY=${NOTIFIARR_API_KEY:-}   # ← executed as command, not written to file
    fi
```

These lines execute variable expansion as no-op commands rather than writing to the config file.

**Same nesting bug in `show_config_summary()`** (lines 305-312) — Notifiarr/Ombi/Seerr blocks are incorrectly nested.

**Wizard cancel doesn't exit gracefully.** If user presses Cancel/Escape on any dialog, the script continues with empty values due to `set -e` not catching dialog's exit code properly when using `$(dialog --stdout ...)`.

**curl-pipe-bash install** (README line 103) runs the entire script as root without verification. No checksum, no GPG signature, no way to review before execution.

---

### 6. Production Readiness Score: **4/10**

| Category | Score | Notes |
|----------|-------|-------|
| Architecture design | 8 | Sound concept, proven pattern |
| Code completeness | 3 | ~40% of services unimplemented, missing cloudflared |
| Code correctness | 3 | Broken nesting, ACME mismatch, Plex network conflict |
| Documentation | 6 | Great guides, but references nonexistent files |
| Security | 4 | Plaintext secrets, no dashboard auth, no file perms |
| Error handling | 4 | No dialog cancel handling, no rollback |
| Idempotency claim | 5 | fstab appends duplicates on re-run, no dedup check |

**Verdict:** Excellent concept and documentation quality, but the code isn't runnable as-is. The three blockers are: (1) incomplete compose generation, (2) ACME/network configuration conflicts, and (3) the corrupted if-statement nesting that appears throughout the latter half of the script.

`★ Insight ─────────────────────────────────────`
The corrupted nesting pattern (lines 700-738) looks like it was caused by iteratively adding Notifiarr/Ombi/Seerr support without restructuring the existing conditionals — each addition was inserted mid-block rather than at the same indentation level. This is a common hazard with heredoc-style bash scripts where the structure isn't enforced by a linter. Running `shellcheck install.sh` would catch most of these issues.
`─────────────────────────────────────────────────`
