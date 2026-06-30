.PHONY: lint test build cleanup check-nix build-nix

NIX_FLAGS := --extra-experimental-features nix-command --extra-experimental-features flakes
NIX_KEEPS := --keep HOME --keep SSH_AUTH_SOCK --keep GITHUB_TOKEN --keep WORKSPACE \
	--keep AWS_ROLE --keep AWS_REGION --keep AWS_DEFAULT_REGION \
	--keep AWS_ACCESS_KEY_ID --keep AWS_SECRET_ACCESS_KEY --keep AWS_SESSION_TOKEN \
	--keep KUBE_CONFIG_PATH --keep KUBECONFIG --keep TERM --keep XDG_DATA_DIRS \
	--keep NIX_SSL_CERT_FILE --keep NIX_PROFILE
NIX_CMD := nix develop $(NIX_FLAGS) --ignore-environment --impure $(NIX_KEEPS) --command bash -c

# Verify Nix is installed
check-nix:
	@command -v nix >/dev/null 2>&1 || { echo >&2 "Error: Nix is not installed. Please install it (e.g., 'curl -L https://nixos.org/nix/install | sh')."; exit 1; }

# Build and enter the nix environment
build-nix: check-nix
	@echo "Ensuring Nix environment is built and ready..."
	@$(NIX_CMD) "true"

# Run the linting script identical to what is used in GitHub workflows
lint: check-nix build-nix
	$(NIX_CMD) "time -p ./run_tests.sh --lint-only -d"

# Run the run_tests.sh script without any options
test: check-nix build-nix
	$(NIX_CMD) "time -p ./run_tests.sh"

# Build up the global plugin cache and validate our examples
build: check-nix build-nix
	$(NIX_CMD) "time -p ./run_tests.sh --build-only -d"

# Accept an ID and run the cleanup.sh script with that ID
# Usage: make cleanup ID=<your-id>
cleanup: check-nix build-nix
	$(NIX_CMD) "time -p ./cleanup.sh $(ID)"
