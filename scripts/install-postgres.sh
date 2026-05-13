#!/bin/bash
set -e

apt-get update
apt-get install -y postgresql postgresql-client gosu apt-utils
apt-get clean
rm -rf /var/lib/apt/lists/*

# Detect installed PG version and drop the default cluster
PG_VERSION=$(ls /etc/postgresql/)
pg_dropcluster --stop "$PG_VERSION" main || true
