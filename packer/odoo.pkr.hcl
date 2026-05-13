source "docker" "odoo" {
  image  = "amazonlinux:2023"
  commit = true
  changes = [
    "EXPOSE 8069",
    "VOLUME /var/lib/odoo",
    "ENTRYPOINT [\"/entrypoint-odoo.sh\"]"
  ]
}

source "amazon-ebs" "odoo" {
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
  ami_name     = "ml-odoo-ami-{{timestamp}}"

  tags = {
    Name      = "ml-odoo-ami"
    Project   = "ml-packer"
    Service   = "odoo"
    ManagedBy = "packer"
  }
}

build {
  name    = "ml-odoo"
  sources = ["source.docker.odoo", "source.amazon-ebs.odoo"]

  # ── Shared : installation ─────────────────────────────────────────────────
  provisioner "shell" {
    only   = ["docker.odoo"]
    script = "../scripts/install-odoo.sh"
  }

  provisioner "shell" {
    only            = ["amazon-ebs.odoo"]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "../scripts/install-odoo.sh"
  }

  # ── Docker uniquement : entrypoint ────────────────────────────────────────
  provisioner "file" {
    only        = ["docker.odoo"]
    source      = "../scripts/odoo-entrypoint.sh"
    destination = "/entrypoint-odoo.sh"
  }

  provisioner "shell" {
    only   = ["docker.odoo"]
    inline = ["chmod +x /entrypoint-odoo.sh"]
  }

  # ── AMI uniquement : odoo.conf placeholder + service systemd ─────────────
  provisioner "shell" {
    only            = ["amazon-ebs.odoo"]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "set -e",
      "cat > /etc/odoo/odoo.conf <<EOF",
      "[options]",
      "db_host     = TO_BE_CONFIGURED",
      "db_port     = 5432",
      "db_user     = odoo",
      "db_password = TO_BE_CONFIGURED",
      "db_name     = odoo",
      "addons_path = /opt/odoo/odoo/addons",
      "data_dir    = /var/lib/odoo",
      "logfile     = /var/log/odoo/odoo.log",
      "EOF",
      "chown odoo:odoo /etc/odoo/odoo.conf",
      "chmod 640 /etc/odoo/odoo.conf",
      "cat > /etc/systemd/system/odoo.service <<EOF",
      "[Unit]",
      "Description=Odoo 17 Community",
      "After=network.target",
      "[Service]",
      "Type=simple",
      "User=odoo",
      "Group=odoo",
      "ExecStart=/usr/bin/python3.11 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf",
      "Restart=on-failure",
      "RestartSec=5",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "systemctl daemon-reload",
      "systemctl enable odoo"
    ]
  }

  post-processor "docker-tag" {
    only       = ["docker.odoo"]
    repository = "ml-odoo"
    tags       = ["latest"]
  }
}
