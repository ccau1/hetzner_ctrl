ENVIRONMENTS := dev staging

# Generate explicit rules for each environment using Make macros
# (Pattern rules don't work reliably with .PHONY in Make 3.81)
define ENV_RULES
$(1)-init:
	@echo "==> Initializing $(1)..."
	@cd terraform/$(1) && terraform init

$(1)-plan: $(1)-init
	@echo "==> Planning $(1)..."
	@cd terraform/$(1) && terraform plan

$(1)-apply: $(1)-init
	@echo "==> Applying $(1)..."
	@cd terraform/$(1) && terraform apply -auto-approve

$(1)-destroy: $(1)-init
	@echo "==> Destroying $(1)..."
	@cd terraform/$(1) && terraform destroy

$(1)-traefik:
	@echo "==> Installing Traefik on $(1) server..."
	@SERVER_IP=$$$$(cd terraform/$(1) && terraform output -raw server_ip 2>/dev/null) && \
	PUB_KEY=$$$$(cd terraform/$(1) && terraform output -raw ssh_public_key_path 2>/dev/null) && \
	PRIV_KEY=$$$$(echo "$$$$PUB_KEY" | sed 's/\.pub$$$$//') && \
	if [ -z "$$$$SERVER_IP" ]; then \
		echo "Error: Could not get server IP. Run 'make $(1)-apply' first."; \
		exit 1; \
	fi && \
	echo "==> Waiting for Docker on $(1) server..." && \
	for i in $$$$(seq 1 60); do \
		if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i "$$$$PRIV_KEY" \
			root@$$$$SERVER_IP 'command -v docker' >/dev/null 2>&1; then \
			break; \
		fi; \
		echo "   Docker not ready yet ($$$$i/60) — retrying in 5s"; \
		sleep 5; \
	done && \
	if ! ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i "$$$$PRIV_KEY" \
		root@$$$$SERVER_IP 'command -v docker' >/dev/null 2>&1; then \
		echo "Error: Docker is not available on $(1) server after waiting."; \
		echo "       The server may still be bootstrapping. Run 'make $(1)-traefik' again in a minute."; \
		exit 1; \
	fi && \
	scp -o StrictHostKeyChecking=accept-new -i "$$$$PRIV_KEY" -r \
		generated/$(1)/docker-compose.yml generated/$(1)/traefik.yml \
		root@$$$$SERVER_IP:/opt/traefik/ && \
	ssh -o StrictHostKeyChecking=accept-new -i "$$$$PRIV_KEY" \
		root@$$$$SERVER_IP 'cd /opt/traefik && docker compose up -d' && \
	echo "==> Traefik started on $(1) ($$$$SERVER_IP)"

$(1)-ssh-key:
	@KEY_PATH="$$$$HOME/.ssh/hetzner_$(1)"; \
	if [ -f "$$$$KEY_PATH" ]; then \
		echo "==> SSH key already exists: $$$$KEY_PATH"; \
	else \
		echo "==> Generating SSH key pair for $(1)..."; \
		ssh-keygen -t ed25519 -C "hetzner-$(1)" -f "$$$$KEY_PATH" -N ""; \
		echo ""; \
		echo "✅ Key pair created:"; \
		echo "   Public:  $$$$KEY_PATH.pub"; \
		echo "   Private: $$$$KEY_PATH"; \
		echo ""; \
		echo "Add this to terraform/$(1)/terraform.tfvars:"; \
		echo "   ssh_public_key_path = \"$$$$KEY_PATH.pub\""; \
	fi; \
	echo ""; \
	echo "==> Adding key to ssh-agent..."; \
	ssh-add "$$$$KEY_PATH" 2>/dev/null || echo "   (ssh-agent not running — you may need to run 'eval \$$(ssh-agent)' first)"

$(1)-secrets:
	@echo "==> GitHub Actions secrets for $(1):"
	@echo ""
	@cd terraform/$(1) && terraform output -raw github_secrets 2>/dev/null || echo "Error: Run 'make $(1)-apply' first."

$(1)-setup: $(1)-apply $(1)-traefik
	@echo ""
	@echo "✅ $(1) environment is ready!"
	@echo "   Server IP: $$$$(cd terraform/$(1) && terraform output -raw server_ip)"
	@echo ""
	@echo "Next steps:"
	@echo "   make $(1)-secrets   → Show GitHub Actions secrets"
	@echo "   make $(1)-destroy   → Tear down $(1)"

endef

$(foreach env,$(ENVIRONMENTS),$(eval $(call ENV_RULES,$(env))))

.PHONY: help fmt validate ssh-keys \
        $(addsuffix -init,$(ENVIRONMENTS)) \
        $(addsuffix -plan,$(ENVIRONMENTS)) \
        $(addsuffix -apply,$(ENVIRONMENTS)) \
        $(addsuffix -destroy,$(ENVIRONMENTS)) \
        $(addsuffix -traefik,$(ENVIRONMENTS)) \
        $(addsuffix -secrets,$(ENVIRONMENTS)) \
        $(addsuffix -ssh-key,$(ENVIRONMENTS)) \
        $(addsuffix -setup,$(ENVIRONMENTS))

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Quick start:"
	@echo "  make <env>-setup     - Full setup: provision server + install Traefik"
	@echo ""
	@echo "Individual steps:"
	@echo "  make <env>-init      - Initialize Terraform"
	@echo "  make <env>-plan      - Plan infrastructure changes"
	@echo "  make <env>-apply     - Apply infrastructure changes"
	@echo "  make <env>-traefik   - Copy generated configs and start Traefik on the server"
	@echo "  make <env>-destroy   - Destroy infrastructure"
	@echo "  make <env>-secrets   - Show GitHub Actions secrets for the environment"
	@echo "  make <env>-ssh-key   - Generate a dedicated SSH key pair for the environment"
	@echo ""
	@echo "Global targets:"
	@echo "  make ssh-keys        - List available SSH public keys"
	@echo "  make fmt             - Format all Terraform files"
	@echo "  make validate        - Validate all environments"

ssh-keys:
	@echo "==> Available SSH public keys:"
	@ls -1 ~/.ssh/*.pub 2>/dev/null || echo "No SSH public keys found in ~/.ssh/"

fmt:
	@cd terraform && terraform fmt -recursive

validate: $(addsuffix -init,$(ENVIRONMENTS))
	@for env in $(ENVIRONMENTS); do \
		echo "==> Validating $$env..."; \
		(cd terraform/$$env && terraform validate) || exit 1; \
	done
	@echo "==> All environments valid."
