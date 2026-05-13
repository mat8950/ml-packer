#!/bin/bash
set -e

# Génération de odoo.conf depuis les variables d'environnement
cat > /etc/odoo/odoo.conf <<EOF
[options]
db_host     = ${DB_HOST:-postgres}
db_port     = ${DB_PORT:-5432}
db_user     = ${POSTGRES_USER:-odoo}
db_password = ${POSTGRES_PASSWORD:-odoo}
db_name     = ${POSTGRES_DB:-odoo}
addons_path = /usr/lib/python3/dist-packages/odoo/addons
data_dir    = /var/lib/odoo
logfile     = /var/log/odoo/odoo.log
EOF

mkdir -p /var/log/odoo
chown odoo:odoo /var/log/odoo /var/lib/odoo

exec gosu odoo /usr/bin/odoo
