# ── Data sources AMI (construites par Packer) ─────────────────────────────────

data "aws_ami" "odoo" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "tag:Project"
    values = ["ml-packer"]
  }
  filter {
    name   = "tag:Service"
    values = ["odoo"]
  }
}

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

data "aws_availability_zones" "available" {
  state = "available"
}

# ── Key pair SSH (générée par Terraform) ──────────────────────────────────────

resource "tls_private_key" "odoo" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "odoo" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.odoo.public_key_openssh
  tags       = { Name = var.ssh_key_name }
}

resource "local_sensitive_file" "odoo_pem" {
  content         = tls_private_key.odoo.private_key_pem
  filename        = "${path.module}/keys/${var.ssh_key_name}.pem"
  file_permission = "0600"
}

# ── Réseau ────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ml-odoo-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "ml-odoo-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "ml-odoo-subnet-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "ml-odoo-subnet-private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "ml-odoo-rt-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── Security Groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "odoo" {
  name        = "ml-odoo-sg"
  description = "Odoo : 8069 public, SSH admin"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Odoo web"
    from_port   = 8069
    to_port     = 8069
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ml-odoo-sg" }
}

resource "aws_security_group" "postgres" {
  name        = "ml-postgres-sg"
  description = "PostgreSQL : 5432 depuis Odoo uniquement"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL depuis Odoo"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.odoo.id]
  }

  ingress {
    description     = "SSH depuis Odoo (bastion)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.odoo.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ml-postgres-sg" }
}

# ── Instance PostgreSQL (sous-réseau privé) ───────────────────────────────────

resource "aws_instance" "postgres" {
  ami                    = data.aws_ami.postgres.id
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.postgres.id]
  key_name               = aws_key_pair.odoo.key_name

  user_data = templatefile("${path.module}/user_data/postgres.sh.tftpl", {})

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = { Name = "ml-postgres-ec2" }
}

# ── Instance Odoo (sous-réseau public) ────────────────────────────────────────

resource "aws_instance" "odoo" {
  ami                    = data.aws_ami.odoo.id
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.odoo.id]
  key_name               = aws_key_pair.odoo.key_name

  user_data = templatefile("${path.module}/user_data/odoo.sh.tftpl", {
    db_host     = aws_instance.postgres.private_ip
    db_password = var.db_password
    db_user     = "odoo"
    db_name     = "odoo"
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = { Name = "ml-odoo-ec2" }

  depends_on = [aws_instance.postgres]
}
