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
- `tofu fmt` runs on commit via a hook, activated by `make init`. CI re-checks
  it, so a bypassed hook fails the build instead of landing unformatted code.

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

## Container Registry access: why no fence

The same coarseness bites the container registry, but the workaround differs.
Registry IAM is **project-scoped only** — there is no per-namespace grant
([an open Scaleway feature request](https://feature-request.scaleway.com/posts/1276/container-registry-iam-permissions-based-on-namespace)),
and `ContainerRegistryFullAccess` is the only permission set that grants push
(it also grants delete; there is no push-only variant). So the `registry-push`
CI identity (its key lives in Woodpecker as `scw_secret_key`, used by the
site-prompts repo) can **push and delete any registry namespace in the project**.

Unlike Object Storage, there is **no bucket-policy equivalent to fence it** — so
the object-storage trick above cannot be applied here. Today the blast radius is
the single `mdijkstra-homepage` namespace, which is why this is accepted. The
tightening lever, when a second namespace CI should not touch appears, is a
**dedicated project** (fail-closed, at the cost of per-project API keys) or
upstream namespace-level IAM if Scaleway ships it — not a fence added later.

**Rotating the key.** The key carries an `expires_at`. On expiry or scheduled
rotation, re-apply it, read the new secret with
`make get KEY=registry_push_secret_key`, and update the `scw_secret_key`
Woodpecker secret. The site-prompts pipeline runs only on tag pushes, so nothing
exercises the key between releases — a lapsed key surfaces as a `401`/`403` at
the next release with no code change, so check the key's expiry first.

## License

Released under the [Zero-Clause BSD](LICENSE) (0BSD) license — public-domain-equivalent, do whatever you like, no attribution required.
