#!/bin/bash
# Script de Auto Despliegue de Odoo 18 para Debian 12
# ------------------------------------------------------

# Colores para mejorar la legibilidad
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para mostrar mensajes
function log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Función para mensajes de advertencia
function warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

# Comprobar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ser ejecutado como root" 
   exit 1
fi

# Variables de configuración
ODOO_USER="odoo"
ODOO_DIR="/opt/odoo"
ODOO_LOG_DIR="/var/log/odoo"
ODOO_CONFIG_DIR="/etc/odoo"
ODOO_VERSION="18.0"
ODOO_SUPERADMIN="admin"
PG_VERSION="15"
PG_USER="odoo"
PG_PASSWORD="$(openssl rand -base64 12)"

log "Iniciando instalación de Odoo 18 en Debian 12..."

# Actualizar el sistema
log "Actualizando sistema..."
apt-get update && apt-get upgrade -y

# Instalar dependencias
log "Instalando dependencias..."
apt-get install -y git wget python3 python3-pip python3-dev python3-venv \
    python3-wheel libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev \
    libssl-dev libpq-dev libjpeg-dev zlib1g-dev libfreetype6-dev \
    fonts-liberation2 libfontconfig1 libjpeg62-turbo libx11-6 libxext6 \
    libxrender1 xfonts-75dpi xfonts-base libnss3-dev nodejs npm

# Instalar wkhtmltopdf para reportes PDF
log "Instalando wkhtmltopdf..."
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb
dpkg -i wkhtmltox_0.12.6.1-2.bullseye_amd64.deb
apt-get install -f -y
rm wkhtmltox_0.12.6.1-2.bullseye_amd64.deb

# Instalar PostgreSQL
log "Instalando PostgreSQL $PG_VERSION..."
apt-get install -y postgresql-$PG_VERSION

# Configurar usuario de PostgreSQL
log "Configurando PostgreSQL para Odoo..."
su - postgres -c "createuser -s $PG_USER"
su - postgres -c "psql -c \"ALTER USER $PG_USER WITH PASSWORD '$PG_PASSWORD';\""

# Crear usuario del sistema para Odoo
log "Creando usuario del sistema para Odoo..."
useradd -m -d $ODOO_DIR -U -r -s /bin/bash $ODOO_USER

# Crear directorios necesarios
log "Configurando directorios para Odoo..."
mkdir -p $ODOO_CONFIG_DIR $ODOO_LOG_DIR
chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG_DIR $ODOO_LOG_DIR

# Descargar Odoo
log "Descargando Odoo $ODOO_VERSION..."
su - $ODOO_USER -c "git clone --depth 1 --branch $ODOO_VERSION https://www.github.com/odoo/odoo $ODOO_DIR/odoo"

# Crear entorno virtual de Python
log "Configurando entorno virtual de Python..."
su - $ODOO_USER -c "python3 -m venv $ODOO_DIR/venv"
su - $ODOO_USER -c "$ODOO_DIR/venv/bin/pip install --upgrade pip"
su - $ODOO_USER -c "$ODOO_DIR/venv/bin/pip install wheel"
su - $ODOO_USER -c "cd $ODOO_DIR/odoo && $ODOO_DIR/venv/bin/pip install -r requirements.txt"

# Configurar archivo de configuración de Odoo
log "Creando archivo de configuración para Odoo..."
cat > $ODOO_CONFIG_DIR/odoo.conf << EOF
[options]
; General options
admin_passwd = $ODOO_SUPERADMIN
db_host = False
db_port = False
db_user = $PG_USER
db_password = $PG_PASSWORD
dbfilter = 
addons_path = $ODOO_DIR/odoo/addons
logfile = $ODOO_LOG_DIR/odoo.log
logrotate = True
log_level = info
xmlrpc_port = 8069
proxy_mode = True
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
data_dir = $ODOO_DIR/data
longpolling_port = 8072
EOF

# Ajustar permisos
chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG_DIR/odoo.conf
chmod 640 $ODOO_CONFIG_DIR/odoo.conf

# Crear directorio para datos
mkdir -p $ODOO_DIR/data
chown $ODOO_USER:$ODOO_USER $ODOO_DIR/data

# Crear servicio systemd
log "Configurando servicio systemd para Odoo..."
cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo 18
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_DIR/venv/bin/python3 $ODOO_DIR/odoo/odoo-bin -c $ODOO_CONFIG_DIR/odoo.conf
StandardOutput=journal+console
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Habilitar e iniciar el servicio
log "Habilitando e iniciando servicio de Odoo..."
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

# Configurar reglas de firewall (si está instalado)
if command -v ufw &> /dev/null; then
    log "Configurando firewall..."
    ufw allow 8069/tcp
    ufw allow 8072/tcp
fi

# Configuración de logrotate para los logs de Odoo
log "Configurando rotación de logs..."
cat > /etc/logrotate.d/odoo << EOF
$ODOO_LOG_DIR/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 $ODOO_USER $ODOO_USER
    sharedscripts
    postrotate
        systemctl reload odoo
    endscript
}
EOF

# Finalización
log "Instalación de Odoo 18 completada"
log "------------------------------------"
log "Información de acceso:"
log "URL: http://$(hostname -I | awk '{print $1}'):8069"
log "Base de datos: Deberá crear una nueva en el primer acceso"
log "Contraseña de administrador: $ODOO_SUPERADMIN"
log "Usuario PostgreSQL: $PG_USER"
log "Contraseña PostgreSQL: $PG_PASSWORD"
warning "Guarde esta información en un lugar seguro!"
log "Para ver los logs: tail -f $ODOO_LOG_DIR/odoo.log"
log "Para reiniciar Odoo: systemctl restart odoo"