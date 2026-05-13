# Étape 0 – Devbox Vagrant

## Objectif

Fournir un environnement de développement reproductible pour tout nouvel employé, sans intervention manuelle après `vagrant up`.

## Prérequis

| Outil | Installation |
|-------|-------------|
| Vagrant | [vagrantup.com](https://www.vagrantup.com/downloads) |
| VirtualBox | [virtualbox.org](https://www.virtualbox.org/) — Intel |
| VMware Fusion | [vmware.com](https://www.vmware.com/products/fusion.html) — Apple Silicon |

## Démarrage

```bash
vagrant up    # Premier lancement : télécharge la box et provisionne
vagrant ssh   # Connexion à la VM
vagrant halt  # Arrêt de la VM
vagrant destroy -f && vagrant up  # Reset complet
```

## Ce qui est provisionné automatiquement

| Outil | Méthode d'installation |
|-------|----------------------|
| Terraform | HashiCorp repo (dnf) |
| Packer | HashiCorp repo (dnf) |
| Ansible | EPEL repo (dnf) |
| AWS CLI v2 | Binaire officiel Amazon (ARM64/x86_64 auto-détecté) |
| Docker CE | Docker repo officiel (dnf) |
| Git | dnf |

## Vérification

```bash
terraform version
ansible --version
aws --version
packer version
docker --version
```

## Ports exposés

| Port hôte | Port VM | Usage |
|-----------|---------|-------|
| 8080 | 8080 | HTTP |
| 8443 | 8443 | HTTPS |
| 2376 | 2376 | Docker daemon |

## Contenu de la VM

- Repo `ml-iac-tp` cloné dans `/home/vagrant/ml-iac-tp`
- Projet courant synchronisé dans `/vagrant`
- Utilisateur `vagrant` ajouté au groupe `docker`

## Notes

- Sur Apple Silicon, l'AWS CLI est automatiquement téléchargé en `aarch64`
- Le SSH agent forwarding est activé (`config.ssh.forward_agent = true`)
- Le nettoyage des logs et caches est effectué en fin de provisionnement
