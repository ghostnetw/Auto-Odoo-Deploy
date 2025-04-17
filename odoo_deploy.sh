#!/bin/bash
# Script de Instalación Automatizada de Odoo para Debian 12 (Bookworm)

# Salir del script en caso de error
set -e

# El script debe ejecutarse como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root" 
   exit 1
fi

# Códigos de colores para mejor legibilidad
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin Color

# Función para imprimir mensajes de estado
print_status() {
    echo -e "${GREEN}[+] $1${NC}"
}

print_error() {
    echo -e "${RED}[!] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Recopilar información necesaria
read -p "Ingrese el nombre para la base de datos de Odoo: " ODOO_DB
read -p "Ingrese el correo electrónico del administrador: " ODOO_USER_EMAIL
read -s -p "Ingrese la contraseña para el usuario administrador: " ODOO_PWD
echo ""
read -p "Ingrese la versión de Odoo a instalar (ej., 17.0): " ODOO_VERSION
read -s -p "Ingrese una contraseña maestra para la administración de bases de datos: " ODOO_MASTER_PWD
echo ""

# Actualizar sistema
print_status "Actualizando paquetes del sistema..."
apt update && apt upgrade -y

# Instalar dependencias
print_status "Instalando dependencias..."
apt install -y git python3-pip build-essential wget python3-dev python3-venv \
    python3-wheel libfreetype6-dev libxml2-dev libzip-dev libldap2-dev \
    libsasl2-dev python3-setuptools node-less libjpeg-dev zlib1g-dev libpq-dev \
    libxslt1-dev libldap2-dev libtiff5-dev libopenjp2-7-dev liblcms2-dev \
    libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev

# Instalar PostgreSQL
print_status "Instalando PostgreSQL..."
apt install -y postgresql postgresql-client

# Instalar la última versión de wkhtmltopdf para reportes
print_status "Instalando la última versión de wkhtmltopdf..."
apt install -y xfonts-75dpi xfonts-base fontconfig libxrender1 libjpeg62-turbo xfonts-encodings

# Obtener información de la última versión de wkhtmltopdf desde la API de GitHub
print_status "Buscando la última versión de wkhtmltopdf..."
WKHTML_LATEST_URL=$(curl -s https://api.github.com/repos/wkhtmltopdf/packaging/releases/latest | grep "browser_download_url.*bookworm_amd64.deb" | cut -d : -f 2,3 | tr -d \")

if [ -z "$WKHTML_LATEST_URL" ]; then
    print_warning "No se pudo determinar la última versión de wkhtmltopdf para Debian Bookworm, usando versión conocida"
    WKHTML_LATEST_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb"
fi

print_status "Descargando wkhtmltopdf desde $WKHTML_LATEST_URL"
cd /tmp
wget -q $WKHTML_LATEST_URL -O wkhtmltox.deb
dpkg -i wkhtmltox.deb || { apt -f install -y && dpkg -i wkhtmltox.deb; }

# Verificar instalación
if command -v wkhtmltopdf >/dev/null 2>&1; then
    print_status "wkhtmltopdf instalado correctamente: $(wkhtmltopdf --version)"
else
    print_error "La instalación de wkhtmltopdf falló"
    exit 1
fi

# Crear usuario odoo si no existe
print_status "Creando usuario odoo..."
if ! id "odoo" &>/dev/null; then
    adduser --system --home=/opt/odoo --group odoo
fi

# Crear usuario PostgreSQL para Odoo
print_status "Creando usuario PostgreSQL..."
su - postgres -c "createuser -s odoo" || echo "Usuario PostgreSQL ya existe"

# Crear base de datos PostgreSQL para Odoo
print_status "Creando base de datos PostgreSQL..."
# Verificar si la base de datos ya existe
DB_EXISTS=$(su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='$ODOO_DB'\"")
if [ "$DB_EXISTS" != "1" ]; then
    su - postgres -c "createdb --owner=odoo --template=template0 --encoding=UNICODE $ODOO_DB"
    print_status "Base de datos $ODOO_DB creada."
else
    print_warning "La base de datos $ODOO_DB ya existe."
fi

# Clonar Odoo desde el repositorio de GitHub
print_status "Clonando repositorio de Odoo Community..."
cd /opt
if [ -d "/opt/odoo/odoo-server" ]; then
    print_warning "El directorio de Odoo ya existe. Verificando actualizaciones..."
    cd /opt/odoo/odoo-server
    git pull origin $ODOO_VERSION
else
    mkdir -p /opt/odoo
    cd /opt/odoo
    git clone https://github.com/odoo/odoo.git --depth 1 --branch $ODOO_VERSION --single-branch odoo-server
fi

# Crear directorio para módulos personalizados
print_status "Creando directorio de módulos personalizados..."
mkdir -p /opt/odoo/custom-addons

# Establecer permisos
chown -R odoo:odoo /opt/odoo

# Crear entorno virtual e instalar requerimientos
print_status "Configurando entorno virtual de Python..."
cd /opt/odoo
python3 -m venv odoo-venv
source odoo-venv/bin/activate
pip3 install wheel
pip3 install -r /opt/odoo/odoo-server/requirements.txt
deactivate

# Crear directorio de registros
print_status "Creando directorio de registros..."
mkdir -p /var/log/odoo
chown -R odoo:odoo /var/log/odoo

# Crear archivo de configuración de Odoo
print_status "Creando archivo de configuración de Odoo..."
mkdir -p /etc/odoo
cat > /etc/odoo/odoo.conf << EOF
[options]
; Configuración General
admin_passwd = $ODOO_MASTER_PWD
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo-server/addons,/opt/odoo/custom-addons
xmlrpc_port = 8069
proxy_mode = True
logfile = /var/log/odoo/odoo-server.log
logrotate = True
log_level = info
list_db = True
db_name = False
EOF

# Ajustar propiedad del archivo de configuración
chown odoo:odoo /etc/odoo/odoo.conf
chmod 640 /etc/odoo/odoo.conf

# Crear archivo de servicio systemd
print_status "Creando servicio systemd..."
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

# Recargar systemd y habilitar el servicio Odoo
print_status "Habilitando servicio de Odoo..."
systemctl daemon-reload
systemctl enable odoo.service
systemctl start odoo.service

# Verificar si el servicio está ejecutándose correctamente
if systemctl is-active --quiet odoo.service; then
    print_status "¡Odoo está instalado y funcionando!"
    print_status "Puedes acceder a Odoo en http://TU_IP_SERVIDOR:8069"
    print_status "Para crear tu primera base de datos:"
    print_status "1. Ve a http://TU_IP_SERVIDOR:8069/web/database/manager"
    print_status "2. Usa la contraseña maestra: $ODOO_MASTER_PWD"
    print_status "3. Crea una nueva base de datos con:"
    print_status "   - Nombre: $ODOO_DB"
    print_status "   - Correo: $ODOO_USER_EMAIL"
    print_status "   - Contraseña: (la que ingresaste)"
else
    print_error "El servicio Odoo no se inició. Verifica los registros: journalctl -u odoo.service"
fi

# Recomendaciones de seguridad
print_warning "RECOMENDACIONES DE SEGURIDAD:"
print_warning "1. Configurar Nginx o Apache como proxy inverso con SSL"
print_warning "2. Cambiar los puertos predeterminados en el archivo de configuración"
print_warning "3. Implementar soluciones de respaldo para tu base de datos"

# Limpieza
print_status "Limpiando..."
rm -f /tmp/wkhtmltox.deb

print_status "¡Instalación completa! Gracias por usar este script."
