# AGENTS.md

## Purpose
This repository manages a Raspberry Pi homelab using Docker Compose stacks, centered around Home Assistant + NGINX and related services.

Primary goal for agents: make safe, minimal, testable infra/config changes without exposing secrets or breaking running services.

## Repository Layout
Top-level folders are mostly independent service stacks:

- `home-assistant/`: Home Assistant compose + config (`config/automation`, `config/blueprints`, UI YAML, scripts).
- `nginx/`: reverse proxy + certbot config (`nginx.conf`, TLS helper scripts).
- `zigbee2mqtt/`, `mqtt/`: Zigbee and Mosquitto configs.
- `monitoring/`: Telegraf/Promtail/Pushgateway stack.
- `wireguard/`, `openvpn/`, `openvpn_old/`: VPN stacks and helper scripts.
- `wyze/`, `ring/`: camera integrations.
- `homer/`, `heimdall/`, `portainer/`, `duckdns/`, `wireshark/`: utility/service dashboards and networking tools.

Most stacks follow this pattern:

1. Service directory
2. `docker-compose.yml`
3. Optional `config/` directory and helper shell scripts

## Working Rules

### 1) Keep changes scoped
- Touch only the relevant service directory unless cross-service wiring is required.
- Avoid broad refactors across multiple stacks in one change.
- Prefer minimal diffs and preserve existing style in each file.

### 2) Secrets and sensitive data
- Never commit credentials, tokens, certificates, private keys, or `.env` secrets.
- Respect `.gitignore` rules, especially for:
  - `home-assistant/config/secrets.yaml`
  - token files (`*.token`)
  - env files (`*.env`, `*.env.*`)
  - VPN artifacts (`*.ovpn`)
- If a change needs a secret, use environment variables or ignored local files and document expected variable names.

### 3) Docker Compose edits
- Keep image/version decisions consistent with the surrounding stack unless asked to upgrade.
- Preserve host-specific mounts and device mappings unless explicitly changing hardware paths.
- Prefer explicit comments for risky/non-obvious settings (privileged mode, host networking, serial device mappings).

### 4) Shell scripts
- Keep scripts POSIX/Bash-compatible as currently written.
- Do not add destructive commands unless explicitly requested.
- If modifying scripts that touch certs/keys/tokens, call out operational impact.

### 5) Home Assistant config changes
- Preserve YAML structure and avoid formatting churn.
- Keep automations focused and readable; place new automation files under `home-assistant/config/automation/` when appropriate.
- Avoid introducing dependencies on custom components unless requested.

## Validation Checklist (before finishing)
Run what is applicable to changed files:

1. YAML sanity checks
- `docker compose -f <service>/docker-compose.yml config`
- For Home Assistant YAML edits, at minimum run a YAML parse/lint pass if available.

2. Script checks
- `bash -n <script>.sh` for edited shell scripts.

3. Diff review
- Confirm no secrets or generated runtime artifacts were added.
- Confirm only intended service folders changed.

If a command cannot be run in this environment, state that clearly and provide the exact command for the user to run.

## Change/Commit Guidance
- Use commit messages scoped by service, e.g.:
  - `nginx: fix certbot volume mount path`
  - `home-assistant: add garage light automation`
  - `zigbee2mqtt: update adapter device mapping`
- Include operational notes when changes may require restart/redeploy:
  - `docker compose -f <service>/docker-compose.yml up -d`

## Agent Response Expectations
When making changes in this repo:

1. State which service(s) are affected.
2. Summarize risk (low/medium/high) and why.
3. List validation performed (or not performed).
4. Provide exact restart/redeploy commands if needed.
