# Raspberry Pi Homelab (Docker Compose)

![Build Status](https://img.shields.io/badge/build-not%20configured-lightgrey)

Docker Compose-based Raspberry Pi homelab focused on Home Assistant, NGINX ingress/TLS, IoT integrations, VPN access, and utility services.

## What's in this repo

Each top-level directory is a mostly independent stack with its own `docker-compose.yml`:

- `home-assistant` - Home Assistant + config
- `nginx` - NGINX reverse proxy + certbot renewer
- `zigbee2mqtt`, `mqtt` - Zigbee and Mosquitto
- `monitoring` - Telegraf, Promtail, Pushgateway, Chronograf
- `wireguard`, `openvpn` - VPN stacks
- `wyze`, `ring` - Camera integrations
- `homer`, `heimdall`, `portainer`, `duckdns`, `wireshark` - Utility services

## Prerequisites

Install on Raspberry Pi OS (or another Linux host):

1. Docker Engine
2. Docker Compose plugin (`docker compose`)
3. Git

Verify:

```bash
docker --version
docker compose version
git --version
```

Optional but recommended:

- Add your user to the `docker` group to avoid `sudo`
- Enable Docker on boot:

```bash
sudo systemctl enable --now docker
```

## Install

```bash
git clone <your-repo-url> /home/pi/Projects
cd /home/pi/Projects
```

## Setup

1. Create required host directories used by bind mounts (adjust as needed):

```bash
mkdir -p \
  /home/pi/Volumes/duckdns-config \
  /home/pi/Volumes/heimdall \
  /home/pi/Volumes/letsencrypt \
  /home/pi/Volumes/certbot \
  /home/pi/Volumes/chronograf \
  /home/pi/Volumes/pushgateway \
  /home/pi/Volumes/portainer-data \
  /home/pi/Volumes/ovpn_data_raspi \
  /home/pi/Volumes/wireguard/etc \
  /home/pi/Volumes/ring
```

2. Create local env files for stacks that require secrets:

```bash
# wireguard
printf 'PASSWORD=<set-a-strong-password>\n' > wireguard/.env.PASSWORD

# optional shared env for compose interpolation (if you prefer)
cat > .env <<'EOF'
DUCKDNS_TOKEN=<duckdns-token>
WYZE_EMAIL=<wyze-email>
WYZE_PASSWORD=<wyze-password>
API_ID=<wyze-api-id>
API_KEY=<wyze-api-key>
WB_USERNAME=<wyze-bridge-user>
WB_PASSWORD=<wyze-bridge-pass>
EOF
```

3. Review device mappings before first run:

- `home-assistant/docker-compose.yml` (`/dev/serial/by-id/...`)
- `zigbee2mqtt/docker-compose.yml` (`/dev/ttyACM*`, `/dev/serial/by-id/...`)

4. Never commit secrets:

- Keep credentials in local ignored files (`.env`, `.env.*`, tokens)
- Keep Home Assistant secrets in `home-assistant/config/secrets.yaml`

## Run

Start one stack:

```bash
docker compose -f home-assistant/docker-compose.yml up -d
```

Start several common stacks:

```bash
docker compose -f mqtt/docker-compose.yml up -d
docker compose -f zigbee2mqtt/docker-compose.yml up -d
docker compose -f home-assistant/docker-compose.yml up -d
docker compose -f nginx/docker-compose.yml up -d
```

Start every stack in this repo:

```bash
for f in */docker-compose.yml; do
  docker compose -f "$f" up -d
done
```

Stop a stack:

```bash
docker compose -f nginx/docker-compose.yml down
```

View logs:

```bash
docker compose -f home-assistant/docker-compose.yml logs -f --tail=200
```

## Validate configs

Before deploying changes:

```bash
# Compose config validation (example)
docker compose -f home-assistant/docker-compose.yml config

# Validate all compose files
for f in */docker-compose.yml; do
  echo "==> $f"
  docker compose -f "$f" config >/dev/null
done
```

Shell script syntax check (when editing scripts):

```bash
bash -n <script>.sh
```

## Update and redeploy

```bash
cd /home/pi/Projects
git pull

# pull updated images for a stack, then redeploy
docker compose -f home-assistant/docker-compose.yml pull
docker compose -f home-assistant/docker-compose.yml up -d
```

## Build badge note

No CI workflow is currently present in `.github/workflows`, so the badge is a placeholder.
If you add GitHub Actions later, replace the badge URL with your workflow badge link.
