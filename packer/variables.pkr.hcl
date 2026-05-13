packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "eu-west-3"
}

variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "db_password" {
  type      = string
  default   = "odoo_password"
  sensitive = true
}
