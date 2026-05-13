source "docker" "postgres" {
  image  = "amazonlinux:2023"
  commit = true
  changes = [
    "EXPOSE 5432",
    "VOLUME /var/lib/pgsql/data",
    "ENTRYPOINT [\"/entrypoint-postgres.sh\"]"
  ]
}

source "amazon-ebs" "postgres" {
  region        = var.aws_region
  instance_type = var.instance_type

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023*-arm64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ssh_username = "ec2-user"
  ami_name     = "ml-postgres-ami-{{timestamp}}"

  tags = {
    Name      = "ml-postgres-ami"
    Project   = "ml-packer"
    Service   = "postgres"
    ManagedBy = "packer"
  }
}

build {
  name    = "ml-postgres"
  sources = ["source.docker.postgres", "source.amazon-ebs.postgres"]

  # ── Shared : installation ─────────────────────────────────────────────────
  provisioner "shell" {
    only   = ["docker.postgres"]
    script = "../scripts/install-postgres.sh"
  }

  provisioner "shell" {
    only            = ["amazon-ebs.postgres"]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "../scripts/install-postgres.sh"
  }

  # ── Docker uniquement : entrypoint ────────────────────────────────────────
  provisioner "file" {
    only        = ["docker.postgres"]
    source      = "../scripts/postgres-entrypoint.sh"
    destination = "/entrypoint-postgres.sh"
  }

  provisioner "shell" {
    only   = ["docker.postgres"]
    inline = ["chmod +x /entrypoint-postgres.sh"]
  }

  # ── AMI uniquement : init cluster + user/db + service ────────────────────
  provisioner "shell" {
    only            = ["amazon-ebs.postgres"]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    environment_vars = ["DB_PASSWORD=${var.db_password}"]
    inline = [
      "set -e",
      "PG_DATA=/var/lib/pgsql/data",
      "sudo -u postgres initdb -D $PG_DATA",
      "sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/\" $PG_DATA/postgresql.conf",
      "echo 'host all all 0.0.0.0/0 md5' >> $PG_DATA/pg_hba.conf",
      "systemctl start postgresql",
      "sudo -u postgres psql -v ON_ERROR_STOP=1 -c \"CREATE USER odoo WITH PASSWORD '$DB_PASSWORD';\"",
      "sudo -u postgres psql -v ON_ERROR_STOP=1 -c \"CREATE DATABASE odoo OWNER odoo;\"",
      "sudo -u postgres psql -v ON_ERROR_STOP=1 -c \"GRANT ALL PRIVILEGES ON DATABASE odoo TO odoo;\"",
      "sudo -u postgres psql -v ON_ERROR_STOP=1 -d odoo -c \"CREATE EXTENSION IF NOT EXISTS \\\"uuid-ossp\\\";\"",
      "sudo -u postgres psql -v ON_ERROR_STOP=1 -d odoo -c \"CREATE EXTENSION IF NOT EXISTS pg_trgm;\"",
      "sudo -u postgres psql -v ON_ERROR_STOP=1 -d odoo -c \"CREATE EXTENSION IF NOT EXISTS unaccent;\"",
      "systemctl stop postgresql",
      "systemctl enable postgresql"
    ]
  }

  post-processor "docker-tag" {
    only       = ["docker.postgres"]
    repository = "ml-postgres"
    tags       = ["latest"]
  }
}
