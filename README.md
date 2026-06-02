# Hetzner Control Plane

Provision and manage per-environment Hetzner Cloud servers (dev, staging, etc.) with Traefik reverse proxy, automated TLS via Let's Encrypt, and Cloudflare wildcard DNS.

Each environment is fully isolated: its own server, firewall, SSH key, Docker network, and DNS wildcard record.

---

## Repository Structure

```
.
├── terraform/
│   ├── _modules/
│   │   └── control_plane/
│   │       ├── main.tf                    # Server, firewall, DNS, config generation
│   │       ├── variables.tf               # Module inputs
│   │       ├── outputs.tf                 # Module outputs
│   │       └── templates/
│   │           ├── docker-compose.yml.tpl # Traefik Docker Compose template
│   │           └── traefik.yml.tpl        # Traefik static config template
│   ├── dev/
│   │   ├── main.tf                        # Calls the control_plane module
│   │   ├── providers.tf                   # Provider versions + credentials
│   │   ├── variables.tf                   # Input variables
│   │   ├── outputs.tf                     # Outputs from the module
│   │   └── terraform.tfvars.example       # Example variable values
│   └── staging/
│       ├── main.tf
│       ├── providers.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── generated/                             # Generated per-environment configs (gitignored)
│   ├── dev/
│   │   ├── docker-compose.yml
│   │   └── traefik.yml
│   └── staging/
│       ├── docker-compose.yml
│       └── traefik.yml
└── README.md
```

---

## Architecture

```
┌─────────────────────────────────────────┐
│  Cloudflare                             │
│  *.dev.tribalorigin.com     →  Dev IP   │
│  *.staging.tribalorigin.com →  Staging IP│
└─────────────────────────────────────────┘
                   │
    ┌──────────────┴──────────────┐
    ▼                             ▼
┌──────────┐                ┌──────────┐
│ Dev      │                │ Staging  │
│ Server   │                │ Server   │
│          │                │          │
│ Traefik  │                │ Traefik  │
│ App A    │                │ App A    │
│ App B    │                │ App B    │
│ Network: │                │ Network: │
│   dev    │                │ staging  │
└──────────┘                └──────────┘
```

Traefik auto-discovers app containers via Docker labels. No manual proxy updates needed when adding or removing apps.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- SSH key pair (or let the Makefile generate one for you)
- Hetzner Cloud API token for each project/environment
- (Optional) Cloudflare API token with `Zone:Read` and `DNS:Edit` permissions

### SSH Keys

By default, Terraform uses `~/.ssh/id_ed25519.pub`. If you want a dedicated key per environment:

```bash
make dev-ssh-key      # Creates ~/.ssh/hetzner_dev
make staging-ssh-key  # Creates ~/.ssh/hetzner_staging
```

Then update `terraform/<env>/terraform.tfvars`:

```hcl
ssh_public_key_path = "~/.ssh/hetzner_dev.pub"
```

To see all available keys:

```bash
make ssh-keys
```

---

## Quick Start with Make

A `Makefile` is provided to run Terraform commands from the repo root:

```bash
make help              # Show all available targets
make dev-apply         # Provision dev server
make dev-traefik       # Install Traefik on dev server
make staging-apply     # Provision staging server
make staging-traefik   # Install Traefik on staging server
make validate          # Validate all environments
```

---

## Provisioning the Dev Server

One command does everything:

```bash
cp terraform/dev/terraform.tfvars.example terraform/dev/terraform.tfvars
# Edit terraform/dev/terraform.tfvars with your dev Hetzner token

make dev-setup
```

This runs:
1. `terraform apply -auto-approve` — provisions the server
2. `scp` + `docker compose up -d` — installs Traefik

It's idempotent — running it again is safe.

### Manual steps (if you prefer)

```bash
cd terraform/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform apply
```

Then copy the generated configs:

```bash
scp -r generated/dev/docker-compose.yml generated/dev/traefik.yml root@<DEV_SERVER_IP>:/opt/traefik/
ssh root@<DEV_SERVER_IP> 'cd /opt/traefik && docker compose up -d'
```

---

## Provisioning the Staging Server

```bash
cp terraform/staging/terraform.tfvars.example terraform/staging/terraform.tfvars
# Edit terraform/staging/terraform.tfvars with your staging Hetzner token

make staging-setup
```

---

## Adding a New Environment (e.g. `prod`)

1. Copy the `staging/` folder and add the env to the Makefile:

```bash
cd terraform
cp -r staging prod
```

Edit the `Makefile` and add `prod` to the `ENVIRONMENTS` list:

```makefile
ENVIRONMENTS := dev staging prod
```

2. Edit `prod/terraform.tfvars.example` → rename to `terraform.tfvars` and update values:

```hcl
hcloud_token = "YOUR_HETZNER_PROD_API_TOKEN"
# Consider a larger server_type and enable_backups = true for production
```

3. Edit `prod/main.tf` and change `environment = "staging"` to `environment = "prod"`.

4. Edit `prod/outputs.tf` descriptions to say "prod" instead of "staging".

5. Provision:

```bash
cd terraform/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform apply
```

6. Install Traefik:

```bash
scp -r generated/prod/docker-compose.yml generated/prod/traefik.yml root@<PROD_SERVER_IP>:/opt/traefik/
ssh root@<PROD_SERVER_IP> 'cd /opt/traefik && docker compose up -d'
```

---

## Deploying Applications

Any application can deploy to an environment by:

1. Joining the environment's shared Docker network (`dev`, `staging`, `prod`)
2. Adding Traefik labels to its `docker-compose.<env>.yml`
3. Using the hostname pattern `appname.<env>.tribalorigin.com`

> The Cloudflare wildcard record `*.<env>` already points all matching subdomains to the environment's server IP.

### Example: Deploying to Dev

```yaml
version: "3.9"
services:
  app:
    image: ghcr.io/user/app:dev
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.dev.tribalorigin.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"
    networks:
      - dev
    restart: unless-stopped

networks:
  dev:
    external: true
```

### Example: Deploying to Staging

```yaml
version: "3.9"
services:
  app:
    image: ghcr.io/user/app:staging
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.staging.tribalorigin.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"
    networks:
      - staging
    restart: unless-stopped

networks:
  staging:
    external: true
```

### GitHub Actions Secrets per Environment

After provisioning, add these secrets to your app repositories for automated deploys:

| Secret | Example Value |
|--------|---------------|
| `DEV_HETZNER_HOST` | `<dev_server_ip>` |
| `DEV_HETZNER_USER` | `root` |
| `DEV_HETZNER_SSH_KEY` | `<private SSH key>` |
| `STAGING_HETZNER_HOST` | `<staging_server_ip>` |
| `STAGING_HETZNER_USER` | `root` |
| `STAGING_HETZNER_SSH_KEY` | `<private SSH key>` |

---

## Environment Summary

| Command | Purpose |
|---------|---------|
| `cd terraform/dev && terraform apply` | Provision / update dev |
| `cd terraform/staging && terraform apply` | Provision / update staging |
| `cd terraform/dev && terraform destroy` | Tear down dev |
| `cd terraform/staging && terraform destroy` | Tear down staging |

---

## SSL / TLS

Traefik uses **Let's Encrypt** to automatically provision and renew TLS certificates for each subdomain.

Cloudflare SSL/TLS mode for all environments: **Full (strict)**

---

## Notes

- **State isolation:** Each environment directory maintains its own Terraform state. No workspaces needed.
- **Hetzner projects:** Dev and staging can be in the same Hetzner project or different ones. Use the appropriate `hcloud_token` in each environment's `terraform.tfvars`.
- **Generated configs:** `generated/<env>/` is gitignored. These are recreated on every `terraform apply`.
- **Server naming:** The Hetzner server name matches the `environment` variable (e.g. `dev`, `staging`).
- **Backups:** Consider enabling `enable_backups = true` for production-like environments.
