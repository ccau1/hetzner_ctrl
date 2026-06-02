resource "hcloud_ssh_key" "deploy" {
  name       = "${var.environment}-deploy"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_firewall" "web" {
  name = "${var.environment}-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "SSH"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS"
  }
}

resource "hcloud_server" "main" {
  name         = var.environment
  server_type  = var.server_type
  image        = "ubuntu-24.04"
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.deploy.id]
  firewall_ids = [hcloud_firewall.web.id]
  backups      = var.enable_backups

  labels = {
    env = var.environment
  }

  # Bootstrap Docker and create app directories
  user_data = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - fail2ban
    runcmd:
      - curl -fsSL https://get.docker.com | sh
      - usermod -aG docker root
      - mkdir -p /opt/traefik /opt/apps
      - docker network create ${var.environment} || true
      - systemctl enable --now docker
  EOF
}

# Cloudflare DNS wildcard record for environment subdomains
resource "cloudflare_record" "wildcard" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "*.${var.environment}"
  type    = "A"
  content = hcloud_server.main.ipv4_address
  ttl     = 1
  proxied = var.cloudflare_proxied
}

# Generate environment-specific Docker Compose file
resource "local_file" "docker_compose" {
  content = templatefile("${path.module}/templates/docker-compose.yml.tpl", {
    environment = var.environment
  })
  filename = "${path.module}/../../../generated/${var.environment}/docker-compose.yml"
}

# Generate environment-specific Traefik config
resource "local_file" "traefik_config" {
  content = templatefile("${path.module}/templates/traefik.yml.tpl", {
    environment = var.environment
  })
  filename = "${path.module}/../../../generated/${var.environment}/traefik.yml"
}
