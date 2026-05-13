packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "odoo" {
  image  = "ubuntu:22.04"
  commit = true
  changes = [
    "EXPOSE 8069",
    "VOLUME /var/lib/odoo",
    "ENTRYPOINT [\"/entrypoint-odoo.sh\"]"
  ]
}

build {
  name    = "ml-odoo"
  sources = ["source.docker.odoo"]

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    script           = "../scripts/install-odoo.sh"
  }

  provisioner "file" {
    source      = "../scripts/odoo-entrypoint.sh"
    destination = "/entrypoint-odoo.sh"
  }

  provisioner "shell" {
    inline = ["chmod +x /entrypoint-odoo.sh"]
  }

  post-processor "docker-tag" {
    repository = "ml-odoo"
    tags       = ["latest"]
  }
}
