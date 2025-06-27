#!/usr/bin/env bash
set -euo pipefail

### 1. Basic system prep
export TZ=UTC
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo "$TZ" > /etc/timezone

# Speed up apt
cat > /etc/apt/apt.conf.d/99custom <<'EOF'
Acquire::http::Pipeline-Depth "0";
Acquire::http::No-Cache "true";
Acquire::BrokenProxy    "true";
EOF

apt-get update && apt-get upgrade -y
apt-get install -y \
  gnupg curl ca-certificates zip unzip git supervisor sqlite3 \
  libcap2-bin libpng-dev python3 dnsutils ffmpeg nano \
  software-properties-common lsb-release apt-transport-https

# Ensure git is installed (redundant if already above, but explicit for clarity)
apt-get install -y git

### 2. Add Ondřej Surý’s PHP PPA and install PHP 8.4 + extensions
curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x4F4EA0AAE5267A6C' \
  | gpg --dearmor \
  | tee /etc/apt/keyrings/ppa_ondrej_php.gpg >/dev/null

echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] \
  https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main" \
  > /etc/apt/sources.list.d/ppa_ondrej_php.list

apt-get update
apt-get install -y \
  php8.4-cli php8.4-fpm php8.4-dev \
  php8.4-pgsql php8.4-sqlite3 php8.4-mysql php8.4-gd \
  php8.4-curl php8.4-imap php8.4-mbstring php8.4-xml \
  php8.4-zip php8.4-bcmath php8.4-soap php8.4-intl \
  php8.4-readline php8.4-ldap \
  php8.4-redis php8.4-memcached php8.4-swoole \
  php8.4-mongodb php8.4-msgpack php8.4-igbinary \
  php8.4-imagick php8.4-pcov php8.4-xdebug

# Give PHP permission to bind to low ports
setcap 'cap_net_bind_service=+ep' /usr/bin/php8.4

### 3. Install Composer & Node toolchain
curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Node.js 22.x
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
npm install -g npm pnpm bun

### 4. Create web user & group
WWWGROUP=1000    # match your host user group if desired
groupadd --force -g "$WWWGROUP" web
useradd -m -s /bin/bash -u 1337 -g "$WWWGROUP" web

### 5. Deploy your application
# Assume your Laravel code is already on /var/www/html
mkdir -p /var/www/html
chown -R web:"$WWWGROUP" /var/www/html
cd /var/www/html
sudo -u web composer install --no-interaction --optimize-autoloader
sudo -u web npm install && sudo -u web npm run build


# Only enable supervisor if not running in Docker
if [ -f /.dockerenv ]; then
  echo "[INFO] Skipping 'systemctl enable --now supervisor' (running inside Docker)"
else
  systemctl enable --now supervisor
fi

### 7. PHP-FPM (for Nginx/Caddy) or built-in serve
# If you’d rather use Nginx or Caddy:
#   apt-get install -y nginx
#   cp /var/www/html/docker/nginx.conf /etc/nginx/sites-available/laravel
#   ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
#   systemctl restart nginx

# ---
# CADDY INSTALL (optional, alternative to Nginx)
# # 1. Install HTTPS transport and GPG tools
# sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

# # 2. Add Caddy’s official GPG key
# curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# # 3. Add the Caddy APT repository
# curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# # 4. Update and install Caddy
# sudo apt update
# sudo apt install caddy

# # 5. (Optional) Enable and check the service
# # For testing in docker use `nohup caddy run --config /etc/caddy/Caddyfile --adapter caddyfile >/var/log/caddy.log 2>&1 &`
# nohup caddy run --config /etc/caddy/Caddyfile --adapter caddyfile >/var/log/caddy.log 2>&1 &`
# # sudo systemctl enable --now caddy
# # sudo systemctl status caddy
# Only run Caddy if not running in Docker
# if [ -f /.dockerenv ]; then
#   nohup caddy run --config /etc/caddy/Caddyfile --adapter caddyfile >/var/log/caddy.log 2>&1 &
# else
#  sudo systemctl enable --now caddy
#  sudo systemctl status caddy
fi
# ---

# Install GitHub CLI
echo "Installing GitHub CLI (gh)..."
apt-get install -y gh

echo "\n---"
echo "To authenticate with GitHub, please run:"
echo "    gh auth login"
echo "---\n"

echo "✅ Laravel 12 on PHP 8.4 is ready!"
