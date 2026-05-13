#!/bin/bash
# Script de déploiement manuel — à exécuter depuis la VM Vagrant
# Usage : ./deploy.sh [docker|ami|terraform|all]
set -e

PACKER_DIR="/vagrant/packer"
TERRAFORM_DIR="/vagrant/terraform"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; exit 1; }

show_menu() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║        ml-packer deploy menu         ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
  echo "  1) Build images Docker (local)"
  echo "  2) Build AMIs AWS"
  echo "  3) Deploy Terraform sur AWS"
  echo "  4) Tout faire (1 + 2 + 3)"
  echo "  5) Destroy infrastructure Terraform"
  echo "  q) Quitter"
  echo ""
  read -rp "Choix : " choice
  case "$choice" in
    1) step_docker ;;
    2) step_ami ;;
    3) step_terraform ;;
    4) step_docker && step_ami && step_terraform ;;
    5) step_destroy ;;
    q) exit 0 ;;
    *) warn "Choix invalide" && show_menu ;;
  esac
}

step_docker() {
  info "Étape 1 — Build images Docker (postgres + odoo)"

  cd "$PACKER_DIR"
  packer init . 2>/dev/null || true

  info "Build postgres Docker..."
  packer build -only="ml-postgres.docker.postgres" . || error "Build Docker postgres échoué"
  success "Image Docker postgres construite : ml-postgres:latest"

  info "Build odoo Docker..."
  packer build -only="ml-odoo.docker.odoo" . || error "Build Docker odoo échoué"
  success "Image Docker odoo construite : ml-odoo:latest"

  echo ""
  docker images | grep -E "ml-postgres|ml-odoo"
  success "Étape 1 terminée"
}

step_ami() {
  info "Étape 2 — Build AMIs AWS (postgres + odoo)"

  # Vérif credentials AWS
  if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    error "AWS_ACCESS_KEY_ID non défini. Source tes credentials : source ~/.bashrc"
  fi

  cd "$PACKER_DIR"
  packer init . 2>/dev/null || true

  info "Build AMI postgres (peut prendre 10-15 min)..."
  packer build -only="ml-postgres.amazon-ebs.postgres" . || error "Build AMI postgres échoué"
  success "AMI postgres créée"

  info "Build AMI odoo (peut prendre 15-20 min, clone Odoo depuis GitHub)..."
  packer build -only="ml-odoo.amazon-ebs.odoo" . || error "Build AMI odoo échoué"
  success "AMI odoo créée"

  echo ""
  aws ec2 describe-images --owners self \
    --filters "Name=tag:Project,Values=ml-packer" \
    --query "Images[*].{Name:Name,AMI:ImageId,Date:CreationDate}" \
    --output table
  success "Étape 2 terminée"
}

step_terraform() {
  info "Étape 3 — Deploy Terraform sur AWS"

  # Vérif credentials AWS
  if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    error "AWS_ACCESS_KEY_ID non défini. Source tes credentials : source ~/.bashrc"
  fi

  # Vérif que les AMIs existent
  AMI_COUNT=$(aws ec2 describe-images --owners self \
    --filters "Name=tag:Project,Values=ml-packer" \
    --query "length(Images)" --output text 2>/dev/null || echo 0)

  if [ "$AMI_COUNT" -lt 2 ]; then
    error "AMIs introuvables (trouvé: $AMI_COUNT/2). Lance d'abord l'étape 2 (Build AMIs)."
  fi

  cd "$TERRAFORM_DIR"

  info "terraform init..."
  terraform init

  info "terraform plan..."
  terraform plan

  echo ""
  read -rp "Appliquer le plan ? (yes/no) : " confirm
  if [ "$confirm" != "yes" ]; then
    warn "Apply annulé."
    return
  fi

  info "terraform apply..."
  terraform apply -auto-approve

  echo ""
  success "Étape 3 terminée — Infrastructure déployée"
  echo ""
  terraform output
}

step_destroy() {
  warn "Cette action va détruire toute l'infrastructure AWS."
  read -rp "Confirmer destroy ? (yes/no) : " confirm
  if [ "$confirm" != "yes" ]; then
    warn "Destroy annulé."
    return
  fi

  cd "$TERRAFORM_DIR"
  terraform destroy -auto-approve
  success "Infrastructure détruite"
}

# ── Entrée du script ──────────────────────────────────────────────────────────

case "${1:-menu}" in
  docker)    step_docker ;;
  ami)       step_ami ;;
  terraform) step_terraform ;;
  all)       step_docker && step_ami && step_terraform ;;
  destroy)   step_destroy ;;
  menu|*)    show_menu ;;
esac
