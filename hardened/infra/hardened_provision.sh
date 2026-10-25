#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PORTAL_REPO="${PORTAL_REPO:-https://github.com/Incogn1mu5/Northernbridge-College-CTF.git}"
PORTAL_BRANCH="${PORTAL_BRANCH:-main}"
PORTAL_SUBDIR="${PORTAL_SUBDIR:-/hardened/www}"
PORTAL_SEED="${PORTAL_SEED:-/hardened/hardened_seed.sql}"
PORTAL_DIR="${PORTAL_DIR:-/var/www/html}"

# Development mode:
# DEV_MODE=1 means the application is supplied by Vagrant's synced
# ./hardened/www -> /var/www/html folder instead of being cloned from GitHub.
DEV_MODE="${DEV_MODE:-0}"

# Location of the host project inside the VM when the project root
# is synced by Vagrant.
LOCAL_PROJECT_DIR="${LOCAL_PROJECT_DIR:-/vagrant}"

BUILD_DIR="${BUILD_DIR:-/opt/northernbridge-src}"
DB_DIR="${DB_DIR:-/var/lib/northernbridge}"
DB_PATH="${DB_PATH:-$DB_DIR/college.db}"

SITE_HOST="${SITE_HOST:-127.0.0.1}"
SITE_PORT="${SITE_PORT:-80}"

log() { printf '\n====================================================\n[%s] %s\n\n' "$(date +%H:%M:%S)" "$*"; }

echo "======================================"
echo " Northernbridge Hardened VM Provisioning"
echo " (provisioning-only build, no host sync)"
echo "======================================"

# ---------------------------------------------------------------------------
# [1/7] System packages
# ---------------------------------------------------------------------------
log "[1/7] Updating packages and installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
    apache2 \
    php \
    libapache2-mod-php \
    php-sqlite3 \
    sqlite3 \
    git \
    curl \
    rsync

# ---------------------------------------------------------------------------
# [2/7] Acquire portal source
# ---------------------------------------------------------------------------

if [ "$DEV_MODE" = "1" ]; then

    log "[2/7] Development mode — using Vagrant synced application..."

    SRC_DIR="$PORTAL_DIR"

    if [ ! -d "$SRC_DIR" ]; then
        echo "ERROR: development application directory '$SRC_DIR' does not exist." >&2
        echo "Make sure Vagrant is syncing ./www to $PORTAL_DIR." >&2
        exit 1
    fi

    echo "  source       : host ./www"
    echo "  VM directory : $SRC_DIR"
    echo "  GitHub clone : disabled"

else

    log "[2/7] Acquiring portal source from $PORTAL_REPO ($PORTAL_BRANCH)..."

    mkdir -p "$BUILD_DIR"

    if [ -d "$BUILD_DIR/.git" ]; then
        echo "  existing checkout found — updating origin and pulling latest..."

        git -C "$BUILD_DIR" remote set-url origin "$PORTAL_REPO"
        git -C "$BUILD_DIR" fetch --depth 1 origin "$PORTAL_BRANCH"
        git -C "$BUILD_DIR" checkout -B "$PORTAL_BRANCH" "origin/$PORTAL_BRANCH"

    else
        echo "  cloning fresh..."

        git clone \
            --depth 1 \
            --branch "$PORTAL_BRANCH" \
            "$PORTAL_REPO" \
            "$BUILD_DIR"
    fi

    SRC_DIR="$BUILD_DIR/$PORTAL_SUBDIR"

    if [ ! -d "$SRC_DIR" ]; then
        echo "ERROR: '$PORTAL_SUBDIR' not found in '$PORTAL_REPO' (branch '$PORTAL_BRANCH')." >&2
        exit 1
    fi

# ------------------------------------------------------------------------
# [3/7] Install the application into the VM-local web root
# ------------------------------------------------------------------------

    log "[3/7] Installing application to $PORTAL_DIR ..."

    mkdir -p "$PORTAL_DIR"

    rsync -a \
        --delete \
        --exclude='database/' \
        "$SRC_DIR/" \
        "$PORTAL_DIR/"

fi

# ---------------------------------------------------------------------------
# [4/7] Apache virtual host
# ---------------------------------------------------------------------------
log "[4/7] Configuring Apache..."

a2enmod -q rewrite >/dev/null 2>&1 || true
a2enmod -q php8.1  >/dev/null 2>&1 || true

cat > /etc/apache2/sites-available/northernbridge.conf <<VHOST
<VirtualHost *:80>

    ServerName northernbridge.local
    ServerAdmin webmaster@northernbridge.local

    DocumentRoot $PORTAL_DIR

    # Custom branded error pages (custom 404/500 instead of Apache defaults).
    ErrorDocument 404 /404.html
    ErrorDocument 500 /500.html

   # Block all dotfiles (.env, .git, etc.) from being served.
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    <Directory $PORTAL_DIR>
        Options -Indexes
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/northernbridge_error.log
    CustomLog \${APACHE_LOG_DIR}/northernbridge_access.log combined

    # Shared runtime includes are never meant to be fetched directly.
    <DirectoryMatch "$PORTAL_DIR/includes">
        Require all denied
    </DirectoryMatch>

    # The SQLite database is only reachable through the application,
    # never served to the browser directly.
    <FilesMatch "\.(db|sqlite|sqlite3)$">
        Require all denied
    </FilesMatch>

</VirtualHost>
VHOST

a2dissite 000-default.conf >/dev/null 2>&1 || true
a2ensite northernbridge.conf  >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# [4a] Production PHP settings
# ---------------------------------------------------------------------------
log "[4a] Applying production PHP settings..."

PHP_INI="/etc/php/8.1/apache2/php.ini"
if [ -f "$PHP_INI" ]; then
    sed -i -E 's/^display_errors\s*=\s*On/display_errors = Off/'       "$PHP_INI"
    sed -i -E 's/^;?log_errors\s*=\s*Off/log_errors = On/'              "$PHP_INI"
    sed -i -E 's/^;?error_reporting\s*=.*/error_reporting = E_ALL/'     "$PHP_INI"
fi

#----------------------------------------------------------------------------
# [5/7] Idempotent database initialization from the seed SQL
# ---------------------------------------------------------------------------
log "[5/7] Initializing the SQLite database (idempotent)..."

mkdir -p "$DB_DIR"

# Locate seed.sql according to the selected mode.
if [ "$DEV_MODE" = "1" ]; then
    # In development mode /vagrant is the host project root.
    SEED_SRC="$LOCAL_PROJECT_DIR/$PORTAL_SEED"

    # Fallback: allow seed.sql to exist inside ./www.
    if [ ! -f "$SEED_SRC" ]; then
        SEED_SRC="$PORTAL_DIR/$PORTAL_SEED"
    fi
else
    # Production mode: seed comes from the cloned source.
    SEED_SRC="$BUILD_DIR/$PORTAL_SEED"

    if [ ! -f "$SEED_SRC" ]; then
        SEED_SRC="$(find "$BUILD_DIR" -maxdepth 2 \
            -name "$PORTAL_SEED" \
            -print -quit 2>/dev/null || true)"
    fi
fi

if [ -z "$SEED_SRC" ] || [ ! -f "$SEED_SRC" ]; then
    echo "ERROR: seed file '$PORTAL_SEED' not found." >&2
    exit 1
fi

echo "Database path: $DB_PATH"
echo "Seed source: $SEED_SRC"

# Create the database only if it does not already exist.
if [ ! -f "$DB_PATH" ]; then
    echo "Creating SQLite database..."
    sqlite3 "$DB_PATH" < "$SEED_SRC"
else
    echo "SQLite database already exists; preserving existing database."
fi

# ---------------------------------------------------------------------------
# [6/7] Admin password hash seeding 
#
# Seed the hardened admin account — fixed, lab-only test credential.
# Same password every provision (no need to hunt for a new one after
# `vagrant up`), hash computed and inserted automatically via PHP's
# password_hash() — never typed or stored as a hash by hand.
# ---------------------------------------------------------------------------
log " [6/7] Seeding hardened admin account..."

ADMIN_USERNAME="helen.carter"
ADMIN_DEPARTMENT="Information Technology"
ADMIN_PASSWORD="Winter2026!"
# LAB-ONLY verification credential for the hardened build. Never given to
# students, never reused from the vulnerable build's seed or decoy data,
# not a real person's password.

php -r '
$db = new SQLite3($argv[1]);
$hash = password_hash($argv[4], PASSWORD_DEFAULT);
$stmt = $db->prepare(
    "INSERT OR IGNORE INTO admins (username, password_hash, name, number, salary, department)
     VALUES (:username, :hash, :name, :number, :salary, :department)"
);
$stmt->bindValue(":username", $argv[2], SQLITE3_TEXT);
$stmt->bindValue(":hash", $hash, SQLITE3_TEXT);
$stmt->bindValue(":name", "Helen Carter", SQLITE3_TEXT);
$stmt->bindValue(":number", "9457623547", SQLITE3_TEXT);
$stmt->bindValue(":salary", 75000, SQLITE3_FLOAT);
$stmt->bindValue(":department", $argv[3], SQLITE3_TEXT);
$stmt->execute();
' "$DB_PATH" "$ADMIN_USERNAME" "$ADMIN_DEPARTMENT" "$ADMIN_PASSWORD"

echo "  hardened admin account seeded (username: $ADMIN_USERNAME)."

# ---------------------------------------------------------------------------
# [7/7] Permissions, restart, verify
# ---------------------------------------------------------------------------
log "[7/7] Setting permissions, restarting Apache and verifying..."

if [ "$DEV_MODE" = "1" ]; then
    echo "Development mode: preserving ownership of synced website folder."
else
    chown -R www-data:www-data "$PORTAL_DIR"
fi

# Database is VM-local in both development and production modes.
chown -R www-data:www-data "$DB_DIR"
chmod 755 "$DB_DIR"

if [ -f "$DB_PATH" ]; then
    chmod 664 "$DB_PATH"
fi

systemctl enable apache2 >/dev/null 2>&1 || true
systemctl restart apache2

# ---------------------------------------------------------------------------
# Ensure every NIC actually has a DHCP-assigned IPv4 address before probing.
# cloud-init's generated netplan config on ubuntu/jammy64 often only covers
# the interface present at image-build time; the second NIC that Vagrant's
# `public_network` adds is frequently left unconfigured, up but lease-less.
# This is a Vagrant/cloud-init compatibility gap, not a host-specific issue
# — force DHCP on every interface and poll for it rather than assuming a
# single fixed sleep is long enough.
# ---------------------------------------------------------------------------
log "Ensuring all network interfaces request a DHCP lease..."

cat > /etc/netplan/90-all-dhcp.yaml <<'NETPLAN'
network:
  version: 2
  ethernets:
    all-eth:
      match:
        name: en*
      dhcp4: true
      dhcp6: false
NETPLAN

chmod 600 /etc/netplan/90-all-dhcp.yaml
netplan apply || true

# Poll instead of a single fixed sleep — DHCP lease time varies by network.
WAIT_SECS=30
for i in $(seq 1 "$WAIT_SECS"); do
    IP_COUNT="$(ip -4 -o addr show scope global | wc -l)"
    [ "$IP_COUNT" -ge 2 ] && break
    sleep 1
done

# ---------------------------------------------------------------------------
# Discover VM adapter IPs (VirtualBox NAT + Bridged)
# ---------------------------------------------------------------------------
# VirtualBox's default NAT adapter always sits on 10.0.2.0/24
# (the VM itself is normally 10.0.2.15, gateway 10.0.2.2).
# Any other global IPv4 address is treated as the bridged adapter.
discover_ips() {
    NAT_IP=""
    BRIDGE_IP=""
    local first_ip=""
    local ip

    while IFS= read -r ip; do
        [ -z "$ip" ] && continue
        [ -z "$first_ip" ] && first_ip="$ip"

        case "$ip" in
            10.0.2.*)
                [ -z "$NAT_IP" ] && NAT_IP="$ip"
                ;;
            *)
                [ -z "$BRIDGE_IP" ] && BRIDGE_IP="$ip"
                ;;
        esac
    done < <(ip -4 -o addr show scope global \
                | awk '{gsub(/\/.*/,"",$4); print $4}')

    # Fallback: if no 10.0.2.x address exists (custom NAT subnet),
    # assume the first interface is the NAT adapter.
    if [ -z "$NAT_IP" ] && [ -n "$first_ip" ]; then
        NAT_IP="$first_ip"
        [ "$BRIDGE_IP" = "$first_ip" ] && BRIDGE_IP=""
    fi
}

# HTTP probe: returns the status code, or an empty string if no host.
check_http() {
    local host="$1"
    [ -z "$host" ] && { echo ""; return; }
    curl -ksS -o /dev/null -w '%{http_code}' \
        "http://${host}:${SITE_PORT}/" 2>/dev/null || echo "ERR"
}

discover_ips

NAT_CODE="$(check_http "$NAT_IP")"
BRIDGE_CODE="$(check_http "$BRIDGE_IP")"

echo "======================================"
echo " Provisioning complete!"
echo "======================================"
echo "  Portal source  : $PORTAL_DIR"
echo "  Database       : $DB_PATH"
echo

if [ -n "$NAT_IP" ]; then
    echo "  [NAT adapter]      http://$NAT_IP:$SITE_PORT/    ->  HTTP ${NAT_CODE:-n/a}"
    echo "                     This site is ONLY accessible from inside the VirtualBox VM."
    echo "                     The host machine will NOT be able to reach this address"
    echo "                     until a port-forward is configured in the Vagrantfile."
else
    echo "  [NAT adapter]      not detected."
fi

echo

if [ -n "$BRIDGE_IP" ]; then
    echo "  [Bridged adapter]  http://$BRIDGE_IP:$SITE_PORT/    ->  HTTP ${BRIDGE_CODE:-n/a}"
    echo "                     This site can be reached by anyone connected to the same"
    echo "                     router / local network as this VM."
else
    echo "  [Bridged adapter]  not detected."
fi

echo

# The lab is considered healthy if at least one adapter serves HTTP 200.
if [ "$NAT_CODE" != "200" ] && [ "$BRIDGE_CODE" != "200" ]; then
    echo "ERROR: site did not respond with HTTP 200 on any interface." >&2
    echo "       NAT    : $NAT_IP    (HTTP ${NAT_CODE:-n/a})" >&2
    echo "       BRIDGE : $BRIDGE_IP (HTTP ${BRIDGE_CODE:-n/a})" >&2
    exit 1
fi

if [ -f "$DB_PATH" ]; then
    echo "  Student rows   : $(sqlite3 "$DB_PATH" 'SELECT COUNT(*) FROM students;')"
fi
