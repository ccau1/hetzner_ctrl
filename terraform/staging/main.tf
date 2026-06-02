module "control_plane" {
  source = "../_modules/control_plane"

  environment         = "staging"
  ssh_public_key_path = var.ssh_public_key_path
  server_type         = var.server_type
  location            = var.location
  enable_backups      = var.enable_backups
  cloudflare_zone_id  = var.cloudflare_zone_id
  cloudflare_proxied  = var.cloudflare_proxied
}
