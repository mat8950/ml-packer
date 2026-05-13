packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "postgres" {
  image  = "ubuntu:22.04"
  commit = true
  changes = [
    "EXPOSE 5432",
    "VOLUME /var/lib/postgresql/data",
    "ENTRYPOINT [\"/entrypoint-postgres.sh\"]",
    "CMD [\"postgres\"]"
  ]
}

build {
  name    = "ml-postgres"
  sources = ["source.docker.postgres"]

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    script           = "../scripts/install-postgres.sh"
  }

  provisioner "file" {
    source      = "../scripts/postgres-entrypoint.sh"
    destination = "/entrypoint-postgres.sh"
  }

  provisioner "shell" {
    inline = ["chmod +x /entrypoint-postgres.sh"]
  }

  post-processor "docker-tag" {
    repository = "ml-postgres"
    tags       = ["latest"]
  }
}
