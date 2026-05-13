#!/bin/bash
set -e

cat > /etc/odoo/odoo.conf <<EOF
[options]
db_host     = ${DB_HOST:-postgres}
db_port     = ${DB_PORT:-5432}
db_user     = ${POSTGRES_USER:-odoo}
db_password = ${POSTGRES_PASSWORD:-odoo}
db_name     = ${POSTGRES_DB:-odoo}
addons_path = /opt/odoo/odoo/addons
data_dir    = /var/lib/odoo
logfile     = /var/log/odoo/odoo.log
EOF

chown odoo:odoo /etc/odoo/odoo.conf
mkdir -p /var/log/odoo
chown odoo:odoo /var/log/odoo /var/lib/odoo

exec runuser -u odoo -- /usr/bin/python3.11 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
