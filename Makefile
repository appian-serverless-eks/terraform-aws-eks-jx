ifeq ($(OS),Windows_NT)
    OS := windows
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        OS := linux
    endif
    ifeq ($(UNAME_S),Darwin)
        OS := darwin
    endif
endif

SHELL_SPEC_DIR ?= /var/tmp
TERRAFORM_VAR_FILE ?= terraform.tfvars
SHELL_SPEC = bin/shellspec/shellspec
TFSEC = bin/tfsec

.DEFAULT_GOAL := help

.PHONY: help
help:
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: apply 
apply: ## Applies Terraform plan w/ auto approve
	@test -s $(TERRAFORM_VAR_FILE) || { echo "The 'apply' rule assumes that variables are provided $(TERRAFORM_VAR_FILE)"; exit 1; }
	terraform apply -auto-approve --var-file $(TERRAFORM_VAR_FILE)

.PHONY: destroy 
destroy: ## Destroys Terraform infrastructure w/ auto approve
	terraform destroy -auto-approve --var-file $(TERRAFORM_VAR_FILE)

.PHONY: init 
init: ## Init the terraform module
	terraform init

.PHONY: lint 
lint: init ## Verifies Terraform syntax
	terraform version
	terraform fmt -check -diff
	terraform validate

.PHONY: fmt
fmt: ## Reformats Terraform files accoring to standard
	terraform fmt

# There is a bug in the latest version which causes a panic.
$(TFSEC): bin ## Installs tfsec
	curl -L "$$(curl -s https://api.github.com/repos/liamg/tfsec/releases/tags/v0.21.0 | grep -o -E "https://.+?-$(OS)-amd64(.exe)?")" > $(TFSEC);\
	chmod +x $(TFSEC)

check-tfsec: ## Check if tfsec is installed
	$(TFSEC) --version

.PHONY: tfsec
tfsec: $(TFSEC) check-tfsec ## Runs tfsec
	$(TFSEC) -e AWS002,AWS017

bin: ## Create bin directory for test binaries
	mkdir bin

$(SHELL_SPEC): bin ## Installs shellspec into bin/shellspec
	git clone https://github.com/shellspec/shellspec.git bin/shellspec

.PHONY: test
test: $(SHELL_SPEC) ## Runs ShellSpec tests
	$(SHELL_SPEC) --format document --warning-as-failure

.PHONY: test-focus
test-focus: $(SHELL_SPEC) ## Runs ShellSpec tests
	$(SHELL_SPEC) --format document --warning-as-failure --focus

.PHONY: clean
clean: ## Deletes temporary files
	rm -rf report
	rm -f jx-requirements.yml
	rm -rf bin

.PHONY: markdown-table
markdown-table: ## Creates markdown tables for in- and output of this module
	terraform-docs markdown table .
