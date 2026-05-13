#!/bin/bash
set -e

apt-get update
apt-get install -y apt-utils wget gnupg2 curl gosu ca-certificates

# Ajout du dépôt officiel Odoo 17
wget -q -O - https://nightly.odoo.com/odoo.key | gpg --dearmor > /usr/share/keyrings/odoo-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/17.0/nightly/deb/ ./" \
  > /etc/apt/sources.list.d/odoo.list

apt-get update
apt-get install -y odoo

apt-get clean
rm -rf /var/lib/apt/lists/*
