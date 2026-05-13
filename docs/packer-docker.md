# Étape 1 – Images Docker via Packer

## Objectif

Construire deux images Docker Ubuntu pré-configurées via Packer : une pour PostgreSQL et une pour Odoo 17, puis les orchestrer avec Docker Compose.

## Architecture

```
packer/
  variables.pkr.hcl       # Plugins et variables partagés
  postgres.pkr.hcl        # Template image ml-postgres (Ubuntu)
  odoo.pkr.hcl            # Template image ml-odoo (Ubuntu)
scripts/
  install-postgres.sh     # Installation PostgreSQL sur Ubuntu
  postgres-entrypoint.sh  # Init cluster + user/db au 1er démarrage
  install-odoo.sh         # Installation Odoo 17 depuis dépôt officiel
  odoo-entrypoint.sh      # Génère odoo.conf depuis les variables d'env
docker/
  docker-compose.yml
  .env
  init.sql
```

## Build des images

Les builds se lancent depuis le dossier `packer/` avec `-only` pour cibler uniquement les sources Docker.

```bash
cd packer/

# Première fois : télécharger les plugins
packer init .

# Builder l'image PostgreSQL
packer build -only="ml-postgres.docker.postgres" .

# Builder l'image Odoo
packer build -only="ml-odoo.docker.odoo" .
```

### Vérifier les images créées

```bash
docker images | grep ml-
# ml-postgres   latest   ...
# ml-odoo       latest   ...
```

## Configuration

Éditer `docker/.env` avant de démarrer :

```env
POSTGRES_USER=odoo
POSTGRES_PASSWORD=odoo_password
POSTGRES_DB=odoo
DB_HOST=postgres
DB_PORT=5432
```

## Démarrage du stack

```bash
cd docker/
docker compose up -d
```

Odoo est accessible sur **http://localhost:8069**

## Commandes utiles

```bash
# Logs en temps réel
docker compose logs -f
docker compose logs -f odoo
docker compose logs -f postgres

# Statut des services
docker compose ps

# Arrêt
docker compose down

# Reset complet (supprime les volumes)
docker compose down -v
```

## Comportement au démarrage

### PostgreSQL
- Au **premier démarrage** (volume vide) : initialise le cluster PostgreSQL, crée l'utilisateur et la base de données depuis les variables d'environnement, exécute `init.sql`
- Aux **démarrages suivants** : réutilise les données du volume sans réinitialisation

### Odoo
- Démarre **uniquement** une fois PostgreSQL `healthy` (`depends_on: condition: service_healthy`)
- `odoo.conf` est généré à chaque démarrage depuis les variables d'environnement

### Persistance
Les volumes `postgres_data` et `odoo_data` survivent à `docker compose down`. Seul `docker compose down -v` les supprime.

## init.sql

Le fichier `docker/init.sql` active les extensions PostgreSQL requises par Odoo :

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
```
