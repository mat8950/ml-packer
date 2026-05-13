#!/bin/bash
set -e

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PG_VERSION=$(ls /usr/lib/postgresql/)
PG_BINDIR="/usr/lib/postgresql/$PG_VERSION/bin"

DB_USER="${POSTGRES_USER:-odoo}"
DB_PASSWORD="${POSTGRES_PASSWORD:-odoo}"
DB_NAME="${POSTGRES_DB:-odoo}"

mkdir -p "$PGDATA"
chown -R postgres:postgres "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "==> Initialisation du cluster PostgreSQL"
  gosu postgres "$PG_BINDIR/initdb" -D "$PGDATA"

  # Autoriser les connexions distantes
  echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
  sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PGDATA/postgresql.conf"

  gosu postgres "$PG_BINDIR/pg_ctl" -D "$PGDATA" -o "-c listen_addresses=localhost" -w start

  gosu postgres psql -v ON_ERROR_STOP=1 <<-EOSQL
    CREATE USER "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
    CREATE DATABASE "$DB_NAME" OWNER "$DB_USER";
    GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
EOSQL

  # Connexion à la base odoo pour activer les extensions
  gosu postgres psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
    CREATE EXTENSION IF NOT EXISTS "unaccent";
EOSQL

  if [ -f /docker-entrypoint-initdb.d/init.sql ]; then
    echo "==> Exécution de init.sql"
    gosu postgres psql -U "$DB_USER" -d "$DB_NAME" -f /docker-entrypoint-initdb.d/init.sql
  fi

  gosu postgres "$PG_BINDIR/pg_ctl" -D "$PGDATA" -m fast -w stop
  echo "==> Initialisation terminée"
fi

exec gosu postgres "$PG_BINDIR/postgres" -D "$PGDATA"
