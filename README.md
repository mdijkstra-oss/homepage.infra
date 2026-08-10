# infra

Desired-state OpenTofu for the personal site stack: provisions the cloud resources, holds the DNS zone, and pins which image versions deploy. Application code lives in its own repos — this one only provisions and deploys.

Scaleway today, but variables, outputs, and naming stay provider-neutral so a move means rewriting resource bodies, not the whole repo.

## Running it

Credentials come from the local `scw` profile (`scw init`); nothing sensitive is committed. `make` wraps tofu and injects the S3 backend keys from that profile:

```bash
make plan
make apply
```

The DeepSeek API key is the one value `make` cannot supply. Export it before any command that touches the backend container:

```bash
export TF_VAR_deepseek_api_key='sk-…'
```

Two things that aren't obvious from the files:

- The tofu **state bucket** is created by hand — it can't hold its own state before it exists. Everything else is tofu-managed.
- `tofu fmt` runs on commit via a hook, activated by `make init`. CI re-checks it, so a bypassed hook fails the build instead of landing unformatted code.

## What the variables control

Four values in `terraform.tfvars` decide what is live.

| Variable | Default | Effect |
|---|---|---|
| `site_release` | `""` | Image tag the site container runs. Empty creates no site container. |
| `backend_release` | `""` | Image tag the backend container runs. Empty creates no backend container. |
| `domain` | `""` | Domain whose zone this configuration writes. Empty creates no records and no custom domains. |
| `domain_delegated` | `false` | Whether the registrar already points at Scaleway's nameservers. Custom domains are only published once it is `true`. |

Deploying is changing a pin and applying; rolling back is changing the same pin back.

## Deploying

**A new site version.** Confirm the site repo tagged and that its release workflow pushed the image. Change `site_release` to that tag, run `make plan` and check that the container is the only thing changing, then `make apply`. Load the site and confirm the new build is serving, then commit the changed pin.

**A new backend version.** Same shape with `backend_release`. Send one chat message through the site to confirm streaming still works before committing.

Rolling either back is the previous tag in the same field. The container is replaced with the older image, and any tag ever pushed remains available. Nothing is persisted between deploys, so there is no state to unwind.

Run `make plan` again after every apply. It should report no changes.

## The custom domain

The domain stays registered with its registrar; only the zone moves here. Certificates are issued by Scaleway against public DNS, so the domain cannot be published until the registrar points at Scaleway's nameservers — which is why this takes three applies rather than one.

Add the domain to Domains and DNS as an external domain in the console, and satisfy the `_scaleway-challenge` TXT record it asks for at the current DNS host. Nothing in this repo creates the zone; it writes into one that already exists.

Set `domain` and apply. This writes the records into the Scaleway zone while the registrar still points elsewhere, so nothing observable changes. Check them against the nameservers directly before going further:

```bash
# What Scaleway will answer once it is authoritative
dig mdijkstra.dev @ns0.dom.scw.cloud
dig MX mdijkstra.dev @ns0.dom.scw.cloud

# What the world still gets
dig mdijkstra.dev
```

Only when the two agree, change the nameservers at the registrar to `ns0.dom.scw.cloud` and `ns1.dom.scw.cloud`. Records carry a 300-second TTL, but the delegation itself is cached for up to three hours by the registry, so allow that long before every resolver is asking Scaleway.

Then set `domain_delegated = true` and apply. Each hostname is published on its container, and Scaleway issues and renews a certificate for it. Generating a certificate takes a few minutes; the apply blocks until it is ready.

> [!IMPORTANT]
> Publishing a hostname runs an HTTP-01 challenge that gives up after three minutes. Applying with `domain_delegated = true` before the delegation has propagated fails, leaves the hostname in `error`, and serves neither HTTP nor HTTPS on it until it is retried.

`legacy_records` in `locals.tf` carries the names still served by the machine this stack replaces, so that repointing the registrar changes nothing observable. Delete the map once nothing answers on that host.

Mail is not part of this stack. The MX record and the `mail` A record point at the registrar's mail platform and are written here only so the zone is complete.

## Bootstrap

A first apply takes four passes, because a credential has to exist before CI can push, and the zone has to answer before a certificate can be issued against it.

Start with both pins empty, no domain set, and no key exported. The plan should contain the registry namespace, the container namespace and the push identity, and neither container. Apply it, then read the push credential and set it as `REGISTRY_PUSH_SECRET_KEY` in both application repos — the registry login takes `nologin` as its username, so the access key is not needed to push:

```bash
make get KEY=registry_push_secret_key
```

Set `domain` now, before either application is built, and read the value the site compiles in:

```bash
make output
```

Set `agent_url` as the site repo's `VITE_AGENT_URL` repository variable. It follows from the domain alone, so it can be set before anything answers on it. This is the one handover with no fallback: `release.yml` reads the variable bare, so a release cut before it is set fails rather than shipping a bundle pointed at a host inside the visitor's own machine. The site's `ci.yml` falls back to a `.invalid` placeholder instead, so pull requests and pushes to `main` stay green in the window before the backend exists.

Have each repo cut a tag and confirm its CI pushed an image. Export `TF_VAR_deepseek_api_key`, set both pins, plan and apply. Both containers now answer on their generated endpoints, and the zone holds records naming them.

Then repoint the registrar and set `domain_delegated`, as above.

## Rotating keys

**The DeepSeek key.** Create the new key with the provider and set the spend cap on it before it is used. Export it as `TF_VAR_deepseek_api_key` and apply; the container redeploys with the new `RESPONSES_AUTH_TOKEN`. Send one message to confirm inference works, and only then revoke the old key with the provider. Rotate rather than edit: the old value stays in the tofu state's version history, so revocation upstream is what retires it.

**The CI key.** It carries `api_key_expires_at`. Bump it and apply, which replaces the key, then update the secret in both application repos:

```bash
make get KEY=registry_push_secret_key
```

Neither pipeline runs except on a tag push, so a stale secret is invisible until the next release fails with a `401`. Check expiry before cutting a release, not after.

## Container Registry access

The `registry-push` identity — its key is a GitHub Actions secret in both application repos — can **push and delete any registry namespace in the project**.

Registry IAM is project-scoped only. There is no per-namespace grant ([an open Scaleway feature request](https://feature-request.scaleway.com/posts/1276/container-registry-iam-permissions-based-on-namespace)), and `ContainerRegistryFullAccess` is the only permission set that grants push — it also grants delete, and there is no push-only variant. Today the reach is the single `mdijkstra-homepage` namespace, which is why this is accepted. The tightening lever, when a second namespace CI should not touch appears, is a **dedicated project** — fail-closed, at the cost of per-project API keys — or upstream namespace-level IAM if Scaleway ships it.

## License

Released under the [Zero-Clause BSD](LICENSE) (0BSD) license — public-domain-equivalent, do whatever you like, no attribution required.
