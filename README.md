# infra

Desired-state OpenTofu for [mdijkstra.dev](https://mdijkstra.dev): the cloud resources, the DNS zone, and the image tags that decide what is live. Application code lives in its own repos.

Running on [Scaleway](https://www.scaleway.com/en/).

## Running it

```bash
export TF_VAR_deepseek_api_key='sk-…'   # the one value make cannot supply
make plan
make apply
```

Credentials come from the local `scw` profile (`scw init`), and `make` injects the relevant environment variables. 

## What is live

Five values in `terraform.tfvars`:

| Variable | Effect |
|---|---|
| `site_release` | Image tag the site container runs. Empty creates no container. |
| `backend_release` | Image tag the backend container runs. Empty creates no container. |
| `dragoman_release` | Image tag the translator container runs. Empty creates no container, and the backend answers through OpenAI directly. |
| `domain` | Zone this configuration writes. Empty creates no records and no custom domains. |
| `domain_delegated` | Whether the registrar points at Scaleway's nameservers. Custom domains publish only once true. |

Deploying is changing a pin and applying; rolling back is changing it back. Nothing persists between deploys, so there is no state to unwind.

## How the backend reaches a model

Set `dragoman_release` and a second container joins the stack. The backend stops holding a model-provider key: it POSTs to the translator, which speaks `openai-completions` to Scaleway's Generative APIs and translates the answer back, so the catalogue is no longer limited to ids answering on `/responses`.

That container is `private`. Scaleway's gateway validates an `X-Auth-Token` header against the `container-invoke` IAM key before a request reaches it, so the translator authenticates no caller itself. Two keys, and neither container holds both:

| credential | held by | opens |
|---|---|---|
| `container-invoke` | backend | the translator container |
| `inference` | translator | Generative APIs |

Clearing `dragoman_release` destroys the container and puts the backend back on OpenAI with `openai_api_key`, which is where it answered before.

> [!NOTE]
> `ContainersPrivateAccess` is project-scoped: the backend can call every private container in the project, not only this one. One exists today. A second would need this revisited before assuming the backend cannot reach it.

## Container Registry access

> [!WARNING]
> The `registry-push` identity CI holds can push and delete **any** registry namespace in the project. Registry IAM is project-scoped only: there is no per-namespace grant ([open feature request](https://feature-request.scaleway.com/posts/1276/container-registry-iam-permissions-based-on-namespace)), and `ContainerRegistryFullAccess` is the only permission set that grants push. Isolating CI means giving it a dedicated project. As of now only one registry in entire project.

## License

Released under the [Zero-Clause BSD](LICENSE) (0BSD) license — public-domain-equivalent, do whatever you like, no attribution required.

## See also

- [homepage.site](https://github.com/mdijkstra-oss/homepage.site) — the frontend this deploys.
- [homepage.backend](https://github.com/mdijkstra-oss/homepage.backend) — the chat agent it answers with.
- [homepage.dragoman](https://github.com/mdijkstra-oss/homepage.dragoman) — the translator that agent talks through.
