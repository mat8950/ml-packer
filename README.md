# ml-packer

Infrastructure as Code – Vagrant devbox + stack Odoo/PostgreSQL via Packer (Docker & AMI) + déploiement Terraform sur AWS.

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Étape 0 – Devbox Vagrant](docs/vagrant.md) | VM Rocky Linux 9 avec tous les outils DevOps |
| [Étape 1 – Images Docker via Packer](docs/packer-docker.md) | Build des images Amazon Linux 2023 + Docker Compose Odoo/PostgreSQL |
| [Étape 2 – AMIs AWS via Packer](docs/packer-ami.md) | Build des AMIs Amazon Linux 2023 ARM64 pour déploiement EC2 |

---

## Prérequis

- [Vagrant](https://www.vagrantup.com/) + [VirtualBox](https://www.virtualbox.org/)
- Credentials AWS IAM avec droits EC2/AMI

---

## Démarrage rapide

### 1. Configurer les credentials

Créer le fichier `credentials.sh` à la racine du projet (jamais commité) :

```bash
#!/bin/bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="eu-west-3"
export TF_VAR_db_password="odoo_password"
```

### 2. Lancer la devbox

```bash
vagrant up
```

`vagrant up` provisionne automatiquement la VM : installe Terraform, Packer, Docker, AWS CLI et configure les credentials AWS depuis `credentials.sh`.

### 3. Déployer

Le déploiement se fait manuellement depuis la VM via le script interactif :

```bash
vagrant ssh -c "~/deploy.sh"
```

Ou en ouvrant une session et en choisissant une étape :

```bash
vagrant ssh
~/deploy.sh
```

```
╔══════════════════════════════════════╗
║        ml-packer deploy menu         ║
╚══════════════════════════════════════╝
  1) Build images Docker (local)
  2) Build AMIs AWS
  3) Deploy Terraform sur AWS
  4) Tout faire (1 + 2 + 3)
  5) Destroy infrastructure Terraform
  q) Quitter
```

> **Note** : l'option 4 enchaîne tout automatiquement. Le build AMI prend ~15-20 min (clone Odoo depuis GitHub). Le déploiement Terraform demande une confirmation avant d'appliquer.

---

## Structure du projet

```
.
├── Vagrantfile                  # Devbox Rocky Linux 9 (4 vCPU / 4 Go)
├── credentials.sh               # Credentials locaux — gitignored
├── deploy.sh                    # Script de déploiement interactif
├── packer/
│   ├── variables.pkr.hcl        # Plugins + variables AWS
│   ├── postgres.pkr.hcl         # Template Docker + AMI PostgreSQL
│   └── odoo.pkr.hcl             # Template Docker + AMI Odoo
├── scripts/
│   ├── install-postgres.sh      # Install PostgreSQL 16 (AL2023)
│   ├── postgres-entrypoint.sh   # Init cluster au démarrage Docker
│   ├── install-odoo.sh          # Install Odoo 17 depuis source (AL2023)
│   └── odoo-entrypoint.sh       # Config Odoo au démarrage Docker
├── docker/
│   ├── docker-compose.yml
│   ├── .env
│   └── init.sql
├── terraform/
│   ├── main.tf                  # VPC, subnets, SG, instances EC2
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── user_data/
│       ├── odoo.sh.tftpl        # Config + init DB + démarrage Odoo
│       └── postgres.sh.tftpl    # Démarrage PostgreSQL
└── docs/
    ├── vagrant.md
    ├── packer-docker.md
    └── packer-ami.md
```

---

## Architecture AWS

```
Internet
   │
   ▼
[Odoo EC2 – t4g.small]   ← subnet public  (10.0.1.0/24)  port 8069
   │
   ▼
[PostgreSQL EC2 – t4g.small] ← subnet privé (10.0.2.0/24)  port 5432
```

- AMIs ARM64 basées sur Amazon Linux 2023
- Région : `eu-west-3` (Paris)
- Clé SSH générée par Terraform → `terraform/keys/` (gitignored)
