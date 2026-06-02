output "server_ip" {
  description = "Public IPv4 address of the server"
  value       = hcloud_server.main.ipv4_address
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.main.id
}

output "domains" {
  description = "Wildcard domain pattern"
  value = var.cloudflare_zone_id != "" ? [
    "*.${var.environment} → configured"
  ] : []
}

output "next_steps" {
  description = "Post-provisioning instructions"
  value       = <<-EOF

✅ ${title(var.environment)} server provisioned!

── 1. Copy Traefik to the server ────────────────────────────

   scp -r generated/${var.environment}/docker-compose.yml generated/${var.environment}/traefik.yml root@${hcloud_server.main.ipv4_address}:/opt/traefik/
   ssh root@${hcloud_server.main.ipv4_address} 'cd /opt/traefik && docker compose up -d'

── 2. Set Cloudflare SSL/TLS mode for ${var.environment} ───────────────────

   Go to: Cloudflare → SSL/TLS → Overview
   Set to: "Full (strict)" (Let's Encrypt certs are publicly trusted)

── 3. Add GitHub Secrets for ${var.environment} deploys ────────────────────

   ${upper(var.environment)}_HETZNER_HOST = ${hcloud_server.main.ipv4_address}
   ${upper(var.environment)}_HETZNER_USER = root
   ${upper(var.environment)}_HETZNER_SSH_KEY = <your private SSH key>

── 4. Deploy an app to ${var.environment} ─────────────────────────────────

   Push to the ${var.environment} branch or trigger the deploy-${var.environment} workflow.

EOF
}

output "ssh_public_key_path" {
  description = "SSH public key path used for this environment"
  value       = var.ssh_public_key_path
}

output "github_secrets" {
  description = "GitHub Actions secrets for deploying to this environment"
  value       = <<-EOF

──────────────── GitHub Actions Secrets ────────────────

${upper(var.environment)}_HETZNER_HOST     = ${hcloud_server.main.ipv4_address}
${upper(var.environment)}_HETZNER_USER     = root
${upper(var.environment)}_HETZNER_SSH_KEY  = <paste contents of ${trimsuffix(var.ssh_public_key_path, ".pub")}>

────────────────────────────────────────────────────────

EOF
}
