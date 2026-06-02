output "server_ip" {
  description = "Public IPv4 address of the staging server"
  value       = module.control_plane.server_ip
}

output "server_id" {
  description = "Hetzner server ID"
  value       = module.control_plane.server_id
}

output "domains" {
  description = "Staging wildcard domain"
  value       = module.control_plane.domains
}

output "next_steps" {
  description = "Post-provisioning instructions"
  value       = module.control_plane.next_steps
}

output "ssh_public_key_path" {
  description = "SSH public key path used for staging"
  value       = module.control_plane.ssh_public_key_path
}

output "github_secrets" {
  description = "GitHub Actions secrets for staging deploys"
  value       = module.control_plane.github_secrets
}
