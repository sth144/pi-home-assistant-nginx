#!/bin/bash

set -euo pipefail

if [ -x "$(command -v docker compose)" ]; then
  compose_cmd=(docker compose)
elif [ -x "$(command -v docker-compose)" ]; then
  compose_cmd=(docker-compose)
else
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

# All domains on the certificate
domains=(
  sth144.duckdns.org
  plex.sth144.duckdns.org
  audiobookshelf.sth144.duckdns.org
  hass.sth144.duckdns.org
  picocluster.sth144.duckdns.org
  portainer.sth144.duckdns.org
  nas.sth144.duckdns.org
  nextcloud.sth144.duckdns.org
  tts-ui.sth144.duckdns.org
  gitlab.sth144.duckdns.org
  joplin.sth144.duckdns.org
  open-webui.sth144.duckdns.org
  scrypted.sth144.duckdns.org
  freecad.sth144.duckdns.org
  calibre.sth144.duckdns.org
  kavita.sth144.duckdns.org
)

main_domain="${domains[0]}"
rsa_key_size=4096

# IMPORTANT:
# /etc/letsencrypt is mapped to /home/pi/Volumes/letsencrypt
# so certs must go here, NOT the /var/www webroot directory.
data_path="/home/pi/Volumes/letsencrypt"

email="sthinds144@gmail.com" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  read -p "Existing data found for $main_domain. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

live_cert_dir="$data_path/live/$main_domain"
archive_cert_dir="$data_path/archive/$main_domain"
renewal_conf="$data_path/renewal/$main_domain.conf"
has_existing_cert=0
bootstrap_cert_created=0
if [ -f "$live_cert_dir/fullchain.pem" ] && [ -f "$live_cert_dir/privkey.pem" ]; then
  has_existing_cert=1
fi

if [ "$has_existing_cert" -eq 1 ] && { [ ! -d "$archive_cert_dir" ] || [ ! -s "$renewal_conf" ]; }; then
  echo "### Found stale bootstrap certificate state for $main_domain; cleaning it up before requesting a real certificate ..."
  rm -rf "$live_cert_dir" "$archive_cert_dir" "$renewal_conf"
  has_existing_cert=0
fi

# Download TLS parameters if missing
if [ ! -e "$data_path/options-ssl-nginx.conf" ] || [ ! -e "$data_path/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/ssl-dhparams.pem"
  echo
fi

if [ "$has_existing_cert" -eq 0 ]; then
  echo "### No existing certificate found for $main_domain; creating temporary bootstrap certificate ..."
  cert_path="/etc/letsencrypt/live/$main_domain"
  mkdir -p "$live_cert_dir"

  "${compose_cmd[@]}" run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1 \
      -keyout '$cert_path/privkey.pem' \
      -out '$cert_path/fullchain.pem' \
      -subj '/CN=localhost'" certbot
  bootstrap_cert_created=1
  echo

  echo "### Starting nginx ..."
  "${compose_cmd[@]}" up --force-recreate -d nginx
  echo
fi

if [ "$bootstrap_cert_created" -eq 1 ]; then
  echo "### Removing temporary bootstrap certificate for $main_domain before requesting the real certificate ..."
  rm -rf "$live_cert_dir" "$archive_cert_dir" "$renewal_conf"
  echo
fi

echo "### Requesting Let's Encrypt certificate for all domains ..."

# Build -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging if required
if [ "$staging" != "0" ]; then
  staging_arg="--staging"
else
  staging_arg=""
fi

for resolver in 1.1.1.1 8.8.8.8; do
  echo "### Checking CAA lookups via resolver $resolver ..."
  for domain in "${domains[@]}"; do
    dig_output="$(dig CAA "$domain" @"$resolver" +noall +comments 2>/dev/null || true)"
    if printf '%s\n' "$dig_output" | grep -q "status: SERVFAIL"; then
      echo "Warning: resolver $resolver returned SERVFAIL for CAA lookup on $domain" >&2
    fi
  done
done
echo

"${compose_cmd[@]}" run --rm --entrypoint "\
  certbot certonly -v --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
"${compose_cmd[@]}" exec -T nginx nginx -s reload

echo "### Done!"
