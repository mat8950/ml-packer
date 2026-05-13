#!/bin/bash
set -e

dnf install -y --allowerasing \
  python3.11 python3.11-devel python3.11-pip \
  git gcc gcc-c++ libpq-devel libxml2-devel libxslt-devel \
  libjpeg-devel libffi-devel openldap-devel \
  bzip2-devel freetype-devel nodejs npm

useradd -m -d /opt/odoo -U -r -s /bin/bash odoo 2>/dev/null || true

for i in 1 2 3; do
  git clone --depth 1 --branch 17.0 --single-branch \
    https://github.com/odoo/odoo.git /opt/odoo/odoo && break
  echo "git clone attempt $i failed, retrying in 10s..."
  rm -rf /opt/odoo/odoo
  sleep 10
done
[ -d /opt/odoo/odoo ] || { echo "git clone failed after 3 attempts"; exit 1; }

pip3.11 install -r /opt/odoo/odoo/requirements.txt

mkdir -p /etc/odoo /var/lib/odoo /var/log/odoo
chown -R odoo:odoo /etc/odoo /var/lib/odoo /var/log/odoo /opt/odoo

dnf clean all
rm -rf /var/cache/dnf
