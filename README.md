# infra

Desired-state OpenTofu for the personal site stack: provisions the cloud
resources and pins which artifact versions deploy. Application code lives in its
own repos — this one only provisions and deploys.

Scaleway today, but variables, outputs, and naming stay provider-neutral so a
move means rewriting resource bodies, not the whole repo.

## Running it

Credentials come from the local `scw` profile (`scw init`); nothing sensitive is
committed. `make` wraps tofu and injects the S3 backend keys from that profile:

    make plan
    make apply

Two things that aren't obvious from the files:

- The tofu **state bucket** is created by hand — it can't hold its own state
  before it exists. Everything else is tofu-managed.
- `tofu fmt` runs on commit via a hook; activate it once with
  `git config core.hooksPath .githooks`.
