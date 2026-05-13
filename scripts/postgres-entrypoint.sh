#!/bin/bash
set -e

PGDATA="${PGDATA:-/var/lib/pgsql/data}"
DB_USER="${POSTGRES_USER:-odoo}"
DB_PASSWORD="${POSTGRES_PASSWORD:-odoo}"
DB_NAME="${POSTGRES_DB:-odoo}"

mkdir -p "$PGDATA"
chown postgres:postgres "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "==> Initialisation du cluster PostgreSQL"
  runuser -u postgres -- initdb -D "$PGDATA"

  echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
  sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PGDATA/postgresql.conf"

  runuser -u postgres -- pg_ctl -D "$PGDATA" -o "-c listen_addresses=localhost" -w start

  runuser -u postgres -- psql -v ON_ERROR_STOP=1 <<EOSQL
CREATE USER "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE "$DB_NAME" OWNER "$DB_USER";
GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
EOSQL

  runuser -u postgres -- psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" <<EOSQL
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
EOSQL

  if [ -f /docker-entrypoint-initdb.d/init.sql ]; then
    runuser -u postgres -- psql -U "$DB_USER" -d "$DB_NAME" -f /docker-entrypoint-initdb.d/init.sql
  fi

  runuser -u postgres -- pg_ctl -D "$PGDATA" -m fast -w stop
fi

exec runuser -u postgres -- postgres -D "$PGDATA"
