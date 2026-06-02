variable "environment" {
  description = "Environment name: dev, staging, prod, etc."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file (~/.ssh/id_ed25519.pub)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "server_type" {
  description = "Hetzner server type. cx23 = 2 Intel vCPU/4GB (~€4)"
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner datacenter: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki)"
  type        = string
  default     = "nbg1"
}

variable "enable_backups" {
  description = "Enable Hetzner's automated server backups (adds ~20% to server cost)"
  type        = bool
  default     = false
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain"
  type        = string
  default     = ""
}

variable "cloudflare_proxied" {
  description = "Enable Cloudflare proxy (CDN + free SSL). true = orange cloud"
  type        = bool
  default     = true
}
