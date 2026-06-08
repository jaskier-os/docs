# Install

Ordered bare-metal runbook to stand up the whole jaskier-os stack on a single host. Each service
repo carries its own deeper docs; "see <repo>" points there. Ports and service set: see
ARCHITECTURE.md.

## 1. Prerequisites

- A Linux host with root (or sudo) for the control-plane node.
- Packages: docker with the buildx plugin, git, curl, unzip.
- Verify: `docker buildx version`, `git --version`.

## 2. Install k3s

Single control-plane node:

```
curl -sfL https://get.k3s.io | sh -
```

k3s ships its own kubectl; run cluster commands as `sudo k3s kubectl ...`. The `flux` CLI is used
for Flux bootstrap and reconcile.

## 3. In-cluster Docker registry

Run a persistent registry on the host, reachable as `localhost:5000`:

```
docker volume create registry-data
docker run -d --restart=always --name registry -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v registry-data:/var/lib/registry \
  registry:2
```

CI pushes images as `localhost:5000/<svc>:<short_sha>` (and `:latest`); deployment manifests
reference the same `localhost:5000/<svc>:<tag>`.

## 4. GitLab runner

- Register a shell runner: `executor=shell`, tags `shell,docker`, `run_untagged=true`.
- Ensure docker + buildx are installed and usable by the runner user on the host.
- Install the deploy SSH key at `/root/.ssh/flux-deploy` (the runner uses it to SSH-clone and push
  to infrastructure/deploy).
- Enable the runner on each buildable service project.
- Turn Auto DevOps OFF at instance level and group level (otherwise it injects unwanted
  code-quality pipelines).

## 5. Flux bootstrap

- Install the Flux controllers: `flux install`.
- Create the `flux-system` GitRepository pointing at the deploy catalog over SSH:
  `ssh://git@10.29.71.1:41922/infrastructure/deploy.git`, branch `main`. The deploy SSH key is a
  user-level SSH key on the GitLab account with repo read access; add the GitLab host:port to the
  Flux source's `known_hosts`.
- Create two Kustomizations against path `./clusters/production`: `infrastructure` (runs first)
  then `apps` (depends on it). Set `prune=true`.

## 6. Secrets + TLS

Secrets and TLS live in infrastructure/deploy with real values (`infrastructure/secrets/*.yaml`,
`tls/*`). This repo is private/internal and intentionally keeps real secrets; Flux applies them as
part of the `infrastructure` Kustomization. That same Kustomization creates the `ai` and `recon`
namespaces. No sanitization step is needed.

## 7. Build images

Push each buildable service repo to `main`; its `.gitlab-ci.yml` builds with
`docker buildx --push` to `localhost:5000` and bumps its tag in infrastructure/deploy.

Buildable services (cluster + built-but-not-deployed): communicator, orchestrator, anthropic-stt,
kokoro-tts, piper-tts, teratts-tts, silero-tts, espeech-tts, translator, ocr, context-mode,
transcriber, chat-history-agent, clickup-agent, reid-agent, security-agent, vision-agent,
web-search-agent, obsidian-agent, pc-agent (jaskier-os); reid-worker, reid-db-handler,
reid-analytics (reid). silero-tts, espeech-tts, transcriber, context-mode, pc-agent, and
obsidian-agent are built but NOT deployed in the cluster (PC-side or unused).

External images used as-is (no build): mongo:7, postgres:16-alpine, nginx:alpine (api-key-gate),
flaresolverr (ghcr), ghcr.io/remsky/kokoro-fastapi.

## 8. Flux reconcile

Either wait for the sync interval or force it:

```
flux reconcile kustomization infrastructure --with-source
flux reconcile kustomization apps --with-source
```

## 9. Verify

```
sudo k3s kubectl get pods -n ai
sudo k3s kubectl get pods -n recon
flux get kustomizations
```

## 10. Clients

Clients are not in the cluster: glasses, phone, desktop, pc, and glasses-mouse are built and
deployed separately to their devices, and the glasses firmware is flashed separately. See each
client repo; client-glasses has a `firmware/` directory with `fetch-os.sh` and flashing docs.
