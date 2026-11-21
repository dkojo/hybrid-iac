# The on-prem side: a Rocky Linux 9 server running systemd and SSH, like a VM in a data centre.
# In CI it runs as a container on the pipeline runner, so it costs nothing.

terraform {
  required_providers {
    docker = { source = "kreuzwerker/docker" }
  }
}

variable "name" { type = string }
variable "ssh_public_key" { type = string }

resource "docker_image" "rocky" {
  name = "hybrid-iac/rocky9-server:local"
  build {
    context = path.module
  }
  triggers = { dockerfile = filesha256("${path.module}/Dockerfile") }
}

resource "docker_container" "server" {
  name          = var.name
  image         = docker_image.rocky.image_id
  hostname      = var.name
  privileged    = true # systemd needs it, as it would on a real VM
  cgroupns_mode = "host"
  command       = ["/usr/sbin/init"]

  volumes {
    host_path      = "/sys/fs/cgroup"
    container_path = "/sys/fs/cgroup"
  }
  ports {
    internal = 22
    external = 2222
  }
  ports {
    internal = 80
    external = 8080
  }
  upload {
    file    = "/home/admin/.ssh/authorized_keys"
    content = var.ssh_public_key
  }
}

output "name" { value = var.name }
output "host" { value = "127.0.0.1" }
output "port" { value = 2222 }
output "user" { value = "admin" }
output "http_url" { value = "http://127.0.0.1:8080" }
