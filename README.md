# ml-packer

Infrastructure as Code – Vagrant devbox + stack Odoo/PostgreSQL via Packer & Docker.

---

## Prérequis

- [Vagrant](https://www.vagrantup.com/) + [VirtualBox](https://www.virtualbox.org/) (ou VMware Fusion sur Apple Silicon)
- [Packer](https://www.packer.io/) 
- [Docker](https://www.docker.com/) + Docker Compose

---

## Étape 0 – Devbox Vagrant

Provisionne une VM Rocky Linux 9 avec tous les outils nécessaires au TP.

**Outils installés automatiquement :**
- Terraform
- Packer
- Ansible
- AWS CLI v2 (ARM64 ou x86_64 détecté automatiquement)
- Docker CE

**Lancer la VM :**

```bash
vagrant up       # Provisionne et démarre la VM
vagrant ssh      # Accès SSH à la VM
```

**Vérifier les installations dans la VM :**

```bash
terraform version
ansible --version
aws --version
packer version
docker --version
```

**Le repo `ml-iac-tp` est cloné automatiquement dans `/home/vagrant/ml-iac-tp`.**

---

## Étape 1 – Stack Odoo en local

Deux images Docker Ubuntu sont construites via Packer : une pour PostgreSQL, une pour Odoo 17.

### 1. Initialiser et builder les images Packer

```bash
cd packer/

# Image PostgreSQL
packer init postgres.pkr.hcl
packer build postgres.pkr.hcl

# Image Odoo
packer init odoo.pkr.hcl
packer build odoo.pkr.hcl
```

Les images `ml-postgres:latest` et `ml-odoo:latest` sont créées localement dans Docker.

### 2. Configurer l'environnement

Éditer `docker/.env` selon les besoins :

```env
POSTGRES_USER=odoo
POSTGRES_PASSWORD=odoo_password
POSTGRES_DB=odoo
DB_HOST=postgres
DB_PORT=5432
```

### Comportement au démarrage

- **PostgreSQL** : initialise le cluster, crée l'utilisateur et la base de données au premier démarrage (volume vide). Les démarrages suivants réutilisent les données persistées.
- **Odoo** : démarre uniquement une fois PostgreSQL `healthy` (via `depends_on` + healthcheck). La configuration est générée depuis les variables d'environnement à chaque démarrage.
- **Persistance** : les volumes `postgres_data` et `odoo_data` survivent aux redémarrages et à `docker compose down`.
