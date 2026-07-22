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

## Object Storage access: why the fence policies

Everything lives in one Scaleway project. The catch is that **Scaleway IAM
cannot scope Object Storage to a single bucket** — the finest grain is the
Project. Their docs put it plainly: *"You can use IAM when you do not need to
configure access to specific buckets, and favor simplicity over granularity …
Bucket policies operate at the bucket level."*
([Combining IAM and bucket policies](https://www.scaleway.com/en/docs/object-storage/api-cli/combining-iam-and-object-storage/))

So the `artifacts-upload` CI identity (its key lives in Woodpecker) necessarily
holds object-write across the **whole** project — every bucket, including the
live site and the Terraform state. We claw that back with per-bucket **fence
policies** (`fence_artifacts_upload` in `iam.tf`): each non-artifacts bucket
allows the owner and explicitly denies the CI application. The list lives in
`fenced_buckets` in `locals.tf`.

**This is fail-open:** add a new bucket and forget to fence it, and the CI key
can write to it. When you add a bucket, add it to `fenced_buckets`.

If this were AWS, none of it would be needed — AWS IAM policies scope to a
bucket/prefix via resource ARNs (`arn:aws:s3:::bucket/releases/*`), so a single
IAM policy would do the job. Scaleway's IAM is coarser, hence the fences. (The
alternative — a dedicated project per identity — is fail-closed but trades this
for per-project API keys, since a key's Object Storage access is bound to one
project.)

## License

Released under the [Zero-Clause BSD](LICENSE) (0BSD) license — public-domain-equivalent, do whatever you like, no attribution required.
