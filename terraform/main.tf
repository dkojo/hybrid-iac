# One Terraform apply provisions both sides of the hybrid estate:
#   - on-prem: a Rocky Linux 9 server (a systemd container standing in for a data-centre VM)
#   - AWS:     an Amazon Linux 2023 EC2 instance in its own small network
# Both modules output the same things (host, port, user), and Terraform writes them into one Ansible inventory.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    docker = { source = "kreuzwerker/docker", version = "~> 4.0" }
    local  = { source = "hashicorp/local", version = "~> 2.5" }
  }
  backend "s3" {
    bucket       = "danielkojomegbenu-tfstate"
    key          = "hybrid-iac/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = { Project = "hybrid-iac", ManagedBy = "terraform" }
  }
}

provider "docker" {}

variable "ssh_public_key" {
  description = "One-time public key the pipeline generates for this run"
  type        = string
}

variable "admin_cidr" {
  description = "The only address allowed to reach the AWS server: the pipeline runner's own IP"
  type        = string
}

module "onprem" {
  source         = "./modules/onprem-server"
  name           = "onprem-rocky"
  ssh_public_key = var.ssh_public_key
}

module "aws" {
  source         = "./modules/aws-server"
  name           = "aws-ec2"
  ssh_public_key = var.ssh_public_key
  admin_cidr     = var.admin_cidr
}

# Same inventory format for both sides: Ansible doesn't care where a server lives
resource "local_file" "inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content         = <<-EOT
    [onprem]
    ${module.onprem.name} ansible_host=${module.onprem.host} ansible_port=${module.onprem.port} ansible_user=${module.onprem.user} env_name=on-prem http_url=${module.onprem.http_url}

    [aws]
    ${module.aws.name} ansible_host=${module.aws.host} ansible_port=${module.aws.port} ansible_user=${module.aws.user} env_name=aws http_url=${module.aws.http_url}
  EOT
}

output "servers" {
  value = {
    onprem = module.onprem.http_url
    aws    = module.aws.http_url
  }
}
