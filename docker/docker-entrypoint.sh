#!/bin/sh
set -eu
cd /var/www/html

# Coolify must mount a persistent volume at /var/www/html/storage.
# The volume may be empty on the very first start, so recreate Laravel's dirs.
mkdir -p \
  storage/app/public \
  storage/framework/cache/data \
  storage/framework/sessions \
  storage/framework/views \
  storage/logs \
  bootstrap/cache

# The installer writes the DB connection and APP_URL into base_path('.env').
# Keep .env inside the persistent storage volume so new image deployments do not
# overwrite the configuration entered through the browser installer.
if [ ! -L .env ]; then
  rm -f .env
  ln -s storage/.env .env
fi

if [ ! -f storage/.env ]; then
  cat > storage/.env <<'ENVFILE'
APP_NAME="Prime Stock"
APP_ENV=production
APP_DEBUG=false
APP_MODE=live
APP_KEY=
APP_URL=http://localhost
LOG_CHANNEL=stack
LOG_LEVEL=warning
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=
DB_USERNAME=
DB_PASSWORD=
BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120
ENVFILE
fi

# Generate the key only once; storage/.env persists across deployments.
if ! grep -q '^APP_KEY=base64:.\{20,\}' storage/.env; then
  php artisan key:generate --force --no-interaction
fi

# Do not run migrate, migrate:fresh, db:seed, or the web installer here.
# Clear compiled caches so changes in a new image are picked up.
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true

chown -R www-data:www-data storage bootstrap/cache
exec "$@"
