#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
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

# Download TLS parameters if missing
if [ ! -e "$data_path/options-ssl-nginx.conf" ] || [ ! -e "$data_path/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $main_domain ..."
cert_path="/etc/letsencrypt/live/$main_domain"
mkdir -p "$data_path/live/$main_domain"

docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1 \
    -keyout '$cert_path/privkey.pem' \
    -out '$cert_path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $main_domain ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$main_domain && \
  rm -Rf /etc/letsencrypt/archive/$main_domain && \
  rm -Rf /etc/letsencrypt/renewal/$main_domain.conf" certbot
echo

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
if [ $staging != "0" ]; then
  staging_arg="--staging"
fi

docker-compose run --rm --entrypoint "\
  certbot certonly -v --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload

echo "### Done!"

