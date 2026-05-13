output "odoo_url" {
  description = "URL d'accès à Odoo"
  value       = "http://${aws_instance.odoo.public_ip}:8069"
}

output "odoo_public_ip" {
  description = "IP publique de l'instance Odoo"
  value       = aws_instance.odoo.public_ip
}

output "postgres_private_ip" {
  description = "IP privée de l'instance PostgreSQL"
  value       = aws_instance.postgres.private_ip
}

output "ssh_key_path" {
  description = "Chemin local vers la clé SSH"
  value       = local_sensitive_file.odoo_pem.filename
}
