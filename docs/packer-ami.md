# Étape 2 – AMIs AWS via Packer

## Objectif

Construire deux AMIs Amazon Linux 2023 via Packer : une pour PostgreSQL 16 et une pour Odoo 17. Chaque service sera déployé sur sa propre instance EC2 via Terraform.

## Architecture

```
packer/
  variables.pkr.hcl         # Plugins, région AWS, instance type, mot de passe DB
  postgres.pkr.hcl          # Template AMI ml-postgres (Amazon Linux 2023)
  odoo.pkr.hcl              # Template AMI ml-odoo (Amazon Linux 2023)
scripts/
  amzn-install-postgres.sh  # Installation PostgreSQL 16 sur AL2023
  amzn-install-odoo.sh      # Installation Odoo 17 (source) sur AL2023
```

## Prérequis AWS

### Credentials

```bash
# Option 1 – Configuration permanente
aws configure

# Option 2 – Variables d'environnement
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="eu-west-3"
```

### Vérification

```bash
aws sts get-caller-identity
aws ec2 describe-vpcs --region eu-west-3 --filters Name=isDefault,Values=true
```

Un VPC par défaut est requis. Si absent, ajouter `vpc_id` et `subnet_id` dans les sources Packer.

### Permissions IAM minimales

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeInstances",
    "ec2:RunInstances",
    "ec2:StopInstances",
    "ec2:TerminateInstances",
    "ec2:CreateImage",
    "ec2:DescribeImages",
    "ec2:DeregisterImage",
    "ec2:CreateSnapshot",
    "ec2:DeleteSnapshot",
    "ec2:CreateKeyPair",
    "ec2:DeleteKeyPair",
    "ec2:CreateSecurityGroup",
    "ec2:DeleteSecurityGroup",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:DescribeSecurityGroups",
    "ec2:DescribeSubnets",
    "ec2:DescribeVpcs",
    "ec2:CreateTags"
  ],
  "Resource": "*"
}
```

## Build des AMIs

```bash
cd packer/

# Première fois uniquement
packer init .

# AMI PostgreSQL (~3-5 min)
packer build -only="ml-postgres.amazon-ebs.postgres" .

# AMI Odoo (~10-15 min — clone Git inclus)
packer build -only="ml-odoo.amazon-ebs.odoo" .
```

### Variables disponibles

| Variable | Défaut | Description |
|----------|--------|-------------|
| `aws_region` | `eu-west-3` | Région AWS |
| `instance_type` | `t3.medium` | Type d'instance de build |
| `db_password` | `odoo_password` | Mot de passe PostgreSQL odoo |

Surcharger une variable :
```bash
packer build -var="aws_region=eu-west-1" -only="ml-postgres.amazon-ebs.postgres" .
```

## Ce que contiennent les AMIs

### AMI PostgreSQL (`ml-postgres-ami`)
- PostgreSQL 16 installé (dépôt natif AL2023)
- Cluster initialisé, user `odoo` et base `odoo` créés
- Extensions `uuid-ossp`, `pg_trgm`, `unaccent` activées
- Accès distant configuré (`listen_addresses = '*'`, `pg_hba.conf` ouvert)
- Service `postgresql` activé mais **non démarré**

### AMI Odoo (`ml-odoo-ami`)
- Python 3.11 + toutes les dépendances installées
- Odoo 17 cloné depuis GitHub dans `/opt/odoo/odoo`
- `odoo.conf` avec des **placeholders** (DB host/password à injecter au lancement)
- Service systemd `odoo` activé mais **non démarré**

## Tags AMI

Les deux AMIs sont taguées pour être trouvables depuis Terraform :

| Tag | Valeur PostgreSQL | Valeur Odoo |
|-----|-------------------|-------------|
| `Name` | `ml-postgres-ami` | `ml-odoo-ami` |
| `Project` | `ml-packer` | `ml-packer` |
| `Service` | `postgres` | `odoo` |
| `ManagedBy` | `packer` | `packer` |

### Lookup Terraform

```hcl
data "aws_ami" "postgres" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "tag:Project"
    values = ["ml-packer"]
  }
  filter {
    name   = "tag:Service"
    values = ["postgres"]
  }
}
```

## Injection de la config Odoo au lancement EC2

La connexion à PostgreSQL est injectée via EC2 user data au démarrage de l'instance Odoo :

```bash
#!/bin/bash
sed -i "s/TO_BE_CONFIGURED/<DB_HOST>/" /etc/odoo/odoo.conf
sed -i "s/TO_BE_CONFIGURED/<DB_PASSWORD>/" /etc/odoo/odoo.conf
systemctl start odoo
```

## Vérifier les AMIs créées

```bash
aws ec2 describe-images \
  --region eu-west-3 \
  --owners self \
  --filters "Name=tag:Project,Values=ml-packer" \
  --query 'Images[*].{Name:Name,ID:ImageId,State:State}'
```
