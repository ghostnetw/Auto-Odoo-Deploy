# Instalación Automatizada de Odoo en Debian 12

Este script automatiza la instalación de Odoo Community Edition en servidores Debian 12 (Bookworm). Proporciona una solución completa que configura todos los componentes necesarios para ejecutar Odoo en un entorno de producción.

## Características

- ✅ Instalación completa de Odoo Community Edition
- ✅ Última versión de wkhtmltopdf para una generación óptima de reportes PDF
- ✅ Configuración de PostgreSQL
- ✅ Configuración de servicios systemd para inicio automático
- ✅ Directorio para módulos personalizados
- ✅ Sistema de permisos adecuado
- ✅ Recomendaciones de seguridad

## Requisitos previos

- Un servidor con Debian 12 Bookworm recién instalado
- Acceso root al servidor
- Conexión a Internet

## Instrucciones de instalación

### 1. Descarga el script de instalación

```bash
wget -O odoo_install.sh https://raw.githubusercontent.com/tu-usuario/odoo-install/main/odoo_install.sh
```

### 2. Otorga permisos de ejecución al script

```bash
chmod +x odoo_install.sh
```

### 3. Ejecuta el script

```bash
sudo ./odoo_install.sh
```

### 4. Sigue las instrucciones interactivas

El script te solicitará:
- Nombre de la base de datos para Odoo
- Correo electrónico del administrador
- Contraseña para el usuario administrador
- Versión de Odoo a instalar (por ejemplo: 17.0)

## Acceso después de la instalación

Una vez completada la instalación, podrás acceder a Odoo en:

```
http://IP-DE-TU-SERVIDOR:8069
```

Para crear tu primera base de datos:
1. Visita la URL anterior
2. Completa el formulario con:
   - Nombre de la base de datos: el que proporcionaste durante la instalación
   - Correo electrónico: el correo que proporcionaste
   - Contraseña: la contraseña que proporcionaste
   - Contraseña maestra: generada durante la instalación

## Estructura de directorios

- `/opt/odoo/odoo-server`: Código fuente de Odoo
- `/opt/odoo/custom-addons`: Directorio para módulos personalizados
- `/opt/odoo/odoo-venv`: Entorno virtual de Python
- `/var/log/odoo`: Archivos de registro
- `/etc/odoo`: Archivos de configuración

## Personalización

### Añadir módulos personalizados

Coloca tus módulos personalizados en:

```
/opt/odoo/custom-addons
```

### Editar la configuración

El archivo de configuración principal se encuentra en:

```
/etc/odoo/odoo.conf
```

### Gestionar el servicio

```bash
# Reiniciar Odoo
sudo systemctl restart odoo

# Ver estado del servicio
sudo systemctl status odoo

# Ver registros
sudo journalctl -u odoo -f
```

## Uso con Enterprise Edition

Si tienes una suscripción válida a Odoo Enterprise:

1. Descarga los módulos Enterprise desde tu portal de Odoo
2. Colócalos en `/opt/odoo/custom-addons`
3. Actualiza la ruta en `/etc/odoo/odoo.conf`:
   ```
   addons_path = /opt/odoo/odoo-server/addons,/opt/odoo/custom-addons,/opt/odoo/enterprise-addons
   ```
4. Reinicia el servicio:
   ```bash
   sudo systemctl restart odoo
   ```
5. Agrega tu clave de licencia a través del menú de Configuración en Odoo

## Recomendaciones de seguridad

Para un entorno de producción, se recomienda:

1. Configurar Nginx o Apache como proxy inverso con SSL
2. Cambiar los puertos predeterminados en el archivo de configuración
3. Implementar soluciones de respaldo para tu base de datos
4. Restringir el acceso a la base de datos con autenticación de PostgreSQL
5. Configurar un firewall (UFW)

## Solución de problemas

### Errores de servicio

Revisa los registros del servicio:
```bash
sudo journalctl -u odoo -f
```

### Problemas de permisos

Si encuentras problemas de permisos:
```bash
sudo chown -R odoo:odoo /opt/odoo
sudo chown -R odoo:odoo /var/log/odoo
```

### Errores de base de datos

Conéctate a PostgreSQL y verifica:
```bash
sudo -u postgres psql
\l
\du
```

## Actualizaciones

Para actualizar Odoo:

```bash
cd /opt/odoo/odoo-server
sudo -u odoo git pull
sudo systemctl restart odoo
```

## Soporte

Para más información y soporte:
- [Documentación oficial de Odoo](https://www.odoo.com/documentation/17.0/)
- [Foro de la comunidad de Odoo](https://www.odoo.com/forum/help-1)

---

**Nota**: Este script es para la Community Edition. Para usar Enterprise Edition, se requiere una suscripción válida de Odoo.
