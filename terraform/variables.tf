variable "aws_region" {
  type    = string
  default = "eu-west-3"
}

variable "db_password" {
  type      = string
  sensitive = true
  description = "Mot de passe PostgreSQL pour l'utilisateur odoo"
}

variable "ssh_key_name" {
  type        = string
  description = "Nom de la key pair AWS générée par Terraform"
  default     = "ml-odoo-keypair"
}
