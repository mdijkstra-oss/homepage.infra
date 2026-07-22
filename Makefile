# Wraps tofu with the S3-backend credentials pulled from the scw CLI profile,
# so no keys are ever written to disk. Usage: `make plan`, `make apply`, etc.
export AWS_ACCESS_KEY_ID     := $(shell scw config get access-key 2>/dev/null)
export AWS_SECRET_ACCESS_KEY := $(shell scw config get secret-key 2>/dev/null)

.PHONY: init reconfigure plan apply fmt validate destroy output get

init:
	tofu init

reconfigure:
	tofu init -reconfigure

plan:
	tofu plan

apply:
	tofu apply

fmt:
	tofu fmt -recursive

validate:
	tofu validate

destroy:
	tofu destroy

output:
	tofu output

# One raw value by name: make get KEY=artifacts_upload_secret_key
get:
	@tofu output -raw $(KEY)
