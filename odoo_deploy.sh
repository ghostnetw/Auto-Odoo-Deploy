#!/bin/bash
# Odoo Community Edition Automated Installation Script for Debian 12 (Bookworm)

# Exit script on any error
set -e

# Script must be run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Color codes for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function for printing status messages
print_status() {
    echo -e "${GREEN}[+] $1${NC}"
}

print_error() {
    echo -e "${RED}[!] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Collect necessary information
read -p "Enter Odoo database name: " ODOO_DB
read -p "Enter Odoo admin username: " ODOO_USER
read -s -p "Enter password for Odoo admin user: " ODOO_PWD
echo ""
read -p "Enter Odoo version to install (e.g., 17.0): " ODOO_VERSION

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install dependencies
print_status "Installing dependencies..."
apt install -y git python3-pip build-essential wget python3-dev python3-venv \
    python3-wheel libfreetype6-dev libxml2-dev libzip-dev libldap2-dev \
    libsasl2-dev python3-setuptools node-less libjpeg-dev zlib1g-dev libpq-dev \
    libxslt1-dev libldap2-dev libtiff5-dev libopenjp2-7-dev liblcms2-dev \
    libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev

# Install PostgreSQL
print_status "Installing PostgreSQL..."
apt install -y postgresql postgresql-client

# Install latest wkhtmltopdf for reports
print_status "Installing latest wkhtmltopdf..."
apt install -y xfonts-75dpi xfonts-base fontconfig libxrender1 libjpeg62-turbo xfonts-encodings

# Get latest wkhtmltopdf release information from GitHub API
print_status "Fetching latest wkhtmltopdf version..."
WKHTML_LATEST_URL=$(curl -s https://api.github.com/repos/wkhtmltopdf/packaging/releases/latest | grep "browser_download_url.*bookworm_amd64.deb" | cut -d : -f 2,3 | tr -d \")

if [ -z "$WKHTML_LATEST_URL" ]; then
    print_warning "Could not determine latest wkhtmltopdf version for Debian Bookworm, falling back to known version"
    WKHTML_LATEST_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb"
fi

print_status "Downloading wkhtmltopdf from $WKHTML_LATEST_URL"
cd /tmp
wget -q $WKHTML_LATEST_URL -O wkhtmltox.deb
dpkg -i wkhtmltox.deb || { apt -f install -y && dpkg -i wkhtmltox.deb; }

# Verify installation
if command -v wkhtmltopdf >/dev/null 2>&1; then
    print_status "wkhtmltopdf installed successfully: $(wkhtmltopdf --version)"
else
    print_error "wkhtmltopdf installation failed"
    exit 1
fi

# Create odoo user if it doesn't exist
print_status "Creating odoo user..."
if ! id "odoo" &>/dev/null; then
    adduser --system --home=/opt/odoo --group odoo
fi

# Create PostgreSQL user for Odoo
print_status "Creating PostgreSQL user..."
su - postgres -c "createuser -s odoo" || echo "PostgreSQL user already exists"

# Clone Odoo from Community GitHub repo
print_status "Cloning Odoo Community repository..."
cd /opt
if [ -d "/opt/odoo/odoo-server" ]; then
    print_warning "Odoo directory already exists. Checking for updates..."
    cd /opt/odoo/odoo-server
    git pull origin $ODOO_VERSION
else
    mkdir -p /opt/odoo
    cd /opt/odoo
    git clone https://github.com/odoo/odoo.git --depth 1 --branch $ODOO_VERSION --single-branch odoo-server
fi

# Set permissions
chown -R odoo:odoo /opt/odoo

# Create virtual environment and install requirements
print_status "Setting up Python virtual environment..."
cd /opt/odoo
python3 -m venv odoo-venv
source odoo-venv/bin/activate
pip3 install wheel
pip3 install -r /opt/odoo/odoo-server/requirements.txt
deactivate

# Create log directory
print_status "Creating log directory..."
mkdir -p /var/log/odoo
chown -R odoo:odoo /var/log/odoo

# Create Odoo configuration file
print_status "Creating Odoo configuration file..."
mkdir -p /etc/odoo
cat > /etc/odoo/odoo.conf << EOF
[options]
; General Configuration
admin_passwd = $ODOO_PWD
db_host = False
db_port = False
db_user = odoo
db_password = False
db_name = $ODOO_DB
addons_path = /opt/odoo/odoo-server/addons
xmlrpc_port = 8069
proxy_mode = True
logfile = /var/log/odoo/odoo-server.log
logrotate = True
log_level = info
EOF

# Adjust ownership of the configuration file
chown odoo:odoo /etc/odoo/odoo.conf
chmod 640 /etc/odoo/odoo.conf

# Create systemd service file
print_status "Creating systemd service..."
cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/odoo-venv/bin/python3 /opt/odoo/odoo-server/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console
Environment=PATH=/opt/odoo/odoo-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable Odoo service
print_status "Enabling Odoo service..."
systemctl daemon-reload
systemctl enable odoo.service
systemctl start odoo.service

# Create the database
print_status "Creating Odoo database..."
su - odoo -c "/opt/odoo/odoo-venv/bin/python3 /opt/odoo/odoo-server/odoo-bin -c /etc/odoo/odoo.conf -d $ODOO_DB -i base --stop-after-init"

# Configure firewall if it's active
if systemctl is-active --quiet ufw; then
    print_status "Configuring firewall..."
    ufw allow 8069/tcp
    ufw reload
fi

# Check if the service is running properly
if systemctl is-active --quiet odoo.service; then
    print_status "Odoo is now installed and running!"
    print_status "You can access Odoo at http://YOUR_SERVER_IP:8069"
    print_status "Database name: $ODOO_DB"
    print_status "Username: $ODOO_USER (email format)"
else
    print_error "Odoo service failed to start. Check logs for details: journalctl -u odoo.service"
fi

# Security recommendations
print_warning "SECURITY RECOMMENDATIONS:"
print_warning "1. Set up Nginx or Apache as a reverse proxy with SSL"
print_warning "2. Change default ports in the configuration file"
print_warning "3. Set up proper backup solutions for your database"

# Cleanup
print_status "Cleaning up..."
rm -f /tmp/wkhtmltox.deb

print_status "Installation complete! Thank you for using this script."
