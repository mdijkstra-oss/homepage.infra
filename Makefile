# Wraps tofu with the S3-backend credentials pulled from the scw CLI profile,
# so no keys are ever written to disk. Usage: `make plan`, `make apply`, etc.
export AWS_ACCESS_KEY_ID     := $(shell scw config get access-key 2>/dev/null)
export AWS_SECRET_ACCESS_KEY := $(shell scw config get secret-key 2>/dev/null)

# .env (gitignored) holds local secrets; exported here so every target sees
# them as TF_VAR_* without a separate bootstrap step.
-include .env
export
export TF_VAR_openai_api_key := $(OPENAI_API_KEY)
export TF_VAR_betterstack_api_token := $(BETTERSTACK_API_TOKEN)

.PHONY: init hooks reconfigure plan apply fmt validate destroy output get state show tofu list

init: hooks
	tofu init

# Git cannot version core.hooksPath, so a fresh clone has no hooks until this
# runs. Wiring it into `init` makes the standard bootstrap enough.
hooks:
	@git config core.hooksPath .githooks

reconfigure:
	tofu init -reconfigure

# -input=false: a missing or unset variable is an error here, never a prompt
# into a non-interactive shell.
# The plan is saved and the apply consumes it, so what is applied is what was
# read. It also gives `apply` an approval it can satisfy without a prompt, which
# -input=false otherwise refuses to supply.
plan:
	tofu plan -input=false -out=tofu.tfplan

apply:
	tofu apply -input=false tofu.tfplan
	@rm -f tofu.tfplan

fmt:
	tofu fmt -recursive

validate:
	tofu validate

destroy:
	tofu destroy

# Inspection needs the same backend credentials as everything else, and reading
# state is the one thing you reach for without already being in a make target.
# make state              — what this configuration manages
# make show ADDR=...      — every attribute of one resource
# make tofu ARGS="..."    — any other subcommand
# What tofu owns. `make list` is the other half: what Better Stack actually has.
state:
	@tofu state list

list:
	@scripts/betterstack-inventory.py

show:
	@tofu state show '$(ADDR)'

tofu:
	@tofu $(ARGS)

output:
	tofu output

# One raw value by name: make get KEY=artifacts_upload_secret_key
get:
	@tofu output -raw $(KEY)
