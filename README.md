# infra

Desired-state OpenTofu for [mdijkstra.dev](https://mdijkstra.dev): the cloud resources, the DNS zone, and the image tags that decide what is live. Application code lives in its own repos.

Scaleway today. Variables, outputs and naming stay provider-neutral, so a move rewrites resource bodies rather than the repo.

## Running it

```bash
export TF_VAR_deepseek_api_key='sk-…'   # the one value make cannot supply
make plan
make apply
```

Credentials come from the local `scw` profile (`scw init`), and `make` injects the S3 backend keys from it. The state bucket is created by hand — it cannot hold its own state before it exists.

## What is live

Four values in `terraform.tfvars`:

| Variable | Effect |
|---|---|
| `site_release` | Image tag the site container runs. Empty creates no container. |
| `backend_release` | Image tag the backend container runs. Empty creates no container. |
| `domain` | Zone this configuration writes. Empty creates no records and no custom domains. |
| `domain_delegated` | Whether the registrar points at Scaleway's nameservers. Custom domains publish only once true. |

Deploying is changing a pin and applying; rolling back is changing it back. Nothing persists between deploys, so there is no state to unwind.

## Rotating keys

**DeepSeek.** Cap the new key before it is used. Export it, apply, confirm inference works, and only then revoke the old one upstream — the old value stays in the state's version history, so revoking upstream is what retires it.

**CI.** Bump `api_key_expires_at`, apply, and push the replaced secret to both repos. 

## Container Registry access

> [!WARNING]
> The `registry-push` identity CI holds can push and delete **any** registry namespace in the project. Registry IAM is project-scoped only: there is no per-namespace grant ([open feature request](https://feature-request.scaleway.com/posts/1276/container-registry-iam-permissions-based-on-namespace)), and `ContainerRegistryFullAccess` is the only permission set that grants push. Isolating CI means giving it a dedicated project. As of now only one registry in entire project.

## License

Released under the [Zero-Clause BSD](LICENSE) (0BSD) license — public-domain-equivalent, do whatever you like, no attribution required.

## See also

- [homepage.site](https://github.com/mdijkstra-oss/homepage.site) — the frontend this deploys.
- [homepage.backend](https://github.com/mdijkstra-oss/homepage.backend) — the chat agent it answers with.
