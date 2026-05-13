# ml-packer

Infrastructure as Code – Vagrant devbox + stack Odoo/PostgreSQL via Packer & Docker.

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Étape 0 – Devbox Vagrant](docs/vagrant.md) | VM Rocky Linux 9 avec tous les outils DevOps |
| [Étape 1 – Images Docker via Packer](docs/packer-docker.md) | Build des images Ubuntu + Docker Compose Odoo/PostgreSQL |
| [Étape 2 – AMIs AWS via Packer](docs/packer-ami.md) | Build des AMIs Amazon Linux 2023 pour déploiement EC2 |

---

## Prérequis

- [Vagrant](https://www.vagrantup.com/) + [VirtualBox](https://www.virtualbox.org/) (ou VMware Fusion sur Apple Silicon)
- [Packer](https://www.packer.io/) ≥ 1.9
- [Docker](https://www.docker.com/) + Docker Compose
- [AWS CLI](https://aws.amazon.com/cli/) + credentials configurés (étape 2)

---

## Démarrage rapide

```bash
# Étape 0 – Lancer la devbox
vagrant up && vagrant ssh

# Étape 1 – Builder les images Docker et lancer Odoo en local
cd packer/
packer init .
packer build -only="ml-postgres.docker.postgres" .
packer build -only="ml-odoo.docker.odoo" .
cd ../docker && docker compose up -d

# Étape 2 – Builder les AMIs AWS
cd packer/
packer build -only="ml-postgres.amazon-ebs.postgres" .
packer build -only="ml-odoo.amazon-ebs.odoo" .
```

---

## Structure du projet

```
.
├── Vagrantfile                  # Devbox Rocky Linux 9
├── packer/
│   ├── variables.pkr.hcl        # Plugins + variables AWS
│   ├── postgres.pkr.hcl         # Template Docker + AMI PostgreSQL
│   └── odoo.pkr.hcl             # Template Docker + AMI Odoo
├── scripts/
│   ├── install-postgres.sh      # Ubuntu – install PostgreSQL
│   ├── postgres-entrypoint.sh   # Ubuntu – init cluster au démarrage
│   ├── install-odoo.sh          # Ubuntu – install Odoo 17
│   ├── odoo-entrypoint.sh       # Ubuntu – config Odoo au démarrage
│   ├── amzn-install-postgres.sh # AL2023 – install PostgreSQL 16
│   └── amzn-install-odoo.sh     # AL2023 – install Odoo 17 (source)
├── docker/
│   ├── docker-compose.yml
│   ├── .env
│   └── init.sql
└── docs/
    ├── vagrant.md
    ├── packer-docker.md
    └── packer-ami.md
```
