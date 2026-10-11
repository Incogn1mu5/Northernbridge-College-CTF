#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PORTAL_REPO="${PORTAL_REPO:-https://github.com/Incogn1mu5/NothernBridge-CTF_phase_3.git}"
PORTAL_BRANCH="${PORTAL_BRANCH:-main}"
PORTAL_SUBDIR="${PORTAL_SUBDIR:-www}"
PORTAL_SEED="${PORTAL_SEED:-seed.sql}"
PORTAL_DIR="${PORTAL_DIR:-/var/www/html}"

# Development mode:
# DEV_MODE=1 means the application is supplied by Vagrant's synced
# ./www -> /var/www/html folder instead of being cloned from GitHub.
DEV_MODE="${DEV_MODE:-0}"

# Location of the host project inside the VM when the project root
# is synced by Vagrant.
LOCAL_PROJECT_DIR="${LOCAL_PROJECT_DIR:-/vagrant}"

BUILD_DIR="${BUILD_DIR:-/opt/northernbridge-src}"
DB_DIR="${DB_DIR:-/var/lib/northernbridge}"
DB_PATH="${DB_PATH:-$DB_DIR/college.db}"
DECOY_ENV="${DECOY_ENV:-$PORTAL_DIR/.env}"
FLAG_DIR="${FLAG_DIR:-/opt/northernbridge}"
FLAG_FILE="${FLAG_FILE:-$FLAG_DIR/flag.txt}"

SITE_HOST="${SITE_HOST:-127.0.0.1}"
SITE_PORT="${SITE_PORT:-80}"

log() { printf '\n====================================================\n[%s] %s\n\n' "$(date +%H:%M:%S)" "$*"; }

echo "======================================"
echo " Northernbridge CTF VM Provisioning"
echo " (provisioning-only build, no host sync)"
echo "======================================"

# ---------------------------------------------------------------------------
# [1/8] System packages
# ---------------------------------------------------------------------------
log "[1/8] Updating packages and installing dependencies..."
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
# [2/8] Acquire portal source
# ---------------------------------------------------------------------------

if [ "$DEV_MODE" = "1" ]; then

    log "[2/8] Development mode — using Vagrant synced application..."

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

    log "[2/8] Acquiring portal source from $PORTAL_REPO ($PORTAL_BRANCH)..."

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
# [3/8] Install the application into the VM-local web root
# ------------------------------------------------------------------------

    log "[3/8] Installing application to $PORTAL_DIR ..."

    mkdir -p "$PORTAL_DIR"

    rsync -a \
        --delete \
        --exclude='database/' \
        "$SRC_DIR/" \
        "$PORTAL_DIR/"

fi

# ---------------------------------------------------------------------------
# [4/8] Apache virtual host
# ---------------------------------------------------------------------------
log "[4/8] Configuring Apache..."

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

    # The decoy .env is intentionally retrievable as a plain-text file.
    # mod_mime treats a fully-hidden filename like ".env" as extensionless,
    # so AddType never matches it; ForceType guarantees text/plain.
    <FilesMatch "^\.env$">
        ForceType text/plain
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

# ---------------------------------------------------------------------------
# [5/8] Decoy credential file (.env) — password-spray stage
# ---------------------------------------------------------------------------
log "[5/8] Placing decoy credential file ($DECOY_ENV)..."

cat > "$DECOY_ENV" <<'ENV'
# Northernbridge College portal — environment configuration
# -----------------------------------------------------
# LAB ONLY — FICTIONAL CREDENTIALS. All usernames and passwords below
# are made up for an offline CTF exercise and describe no real system,
# account, or person. They must never be reused outside this lab.
# -----------------------------------------------------
APP_ENV=production
APP_URL=http://northernbridge.local
APP_DEBUG=false

DB_CONNECTION=sqlite
DB_DATABASE=/var/www/html/database/college.db

# ---------------------------------------------------------------------
# Administrative access
# The production account rotates on an irregular schedule. The pairs
# below were recovered from old support tickets while the IT office
# was migrating between systems. ONLY ONE pair is currently valid;
# the remainder are retired keepers left in place for the archive.
# ---------------------------------------------------------------------
helen.carter:Winter2026!
anil.mehta:Northbridge@2026
priya.kannan:CollegeAdmin!99
david.okafor:Admin#2024
sara.ahmed:PortalPass!7
mohammed.khan:SecureIT@21
lina.farouk:NBCadmin2023
rohan.singh:FallBack!88
emily.wong:Winter2025!
gregory.adams:Admin1@one
fatima.hassan:Autumn#2022
peter.novak:March2026!
ENV
echo "  decoy .env written."

# ---------------------------------------------------------------------------
# [6/8] Final flag — filesystem, outside the database
# ---------------------------------------------------------------------------
log "[6/8] Placing final flag on the filesystem (not in the database)..."

mkdir -p "$FLAG_DIR"

if [ -f "$FLAG_FILE" ]; then
    echo "  Flag already present — leaving in place (unique per deployment)."
else
    TOKEN="$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
    NCC_FLAG="NCC{$TOKEN}"
    cat > "$FLAG_FILE" <<FLAG
Northernbridge College CTF — Final Flag

Congratulations: Here is Your flag for successfully exploiting Local File Inclusion Vulnerability

$NCC_FLAG
FLAG
    echo "  final flag written to $FLAG_FILE"
fi

chown root:www-data "$FLAG_FILE"
chmod 640 "$FLAG_FILE"

# Remove the legacy flag path used by earlier versions of this script.
rm -f "$FLAG_DIR/flag-final.txt"

# ---------------------------------------------------------------------------
# [7/8] Idempotent database initialization from the seed SQL
# ---------------------------------------------------------------------------
log "[7/8] Initializing the SQLite database (idempotent)..."

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

# Converge existing deployments onto the current CTF state: rotate the
# admin credential (only ONE .env pair stays valid), set the department
# the clerk view is scoped to, and remove the legacy in-DB final flag.
MIGRATE="$(cat <<'SQL'
UPDATE admins
   SET password = 'Winter2026!',
       department = 'Information Technology'
 WHERE username = 'helen.carter';

DELETE FROM flags WHERE flag_name = 'Flag_04';

INSERT OR IGNORE INTO compliance_notes
    (id, note, note_date)
VALUES
    (1, 'Full audit log archived at /opt/northernbridge/flag.txt (lab host only).', '2026-09-01'),
    (2, 'All student records remain subject to the clerk view restriction.', '2026-09-01'),
    (3, 'Quarterly data-protection review is scheduled before the spring term.', '2026-09-01');
SQL
)"
sqlite3 "$DB_PATH" "$MIGRATE"

# ---------------------------------------------------------------------------
# [8/8] Permissions, restart, verify
# ---------------------------------------------------------------------------
log "[8/8] Setting permissions, restarting Apache and verifying..."

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

sleep 2

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
echo "  Decoy .env     : $DECOY_ENV"
echo "  Final flag     : $FLAG_FILE"
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
