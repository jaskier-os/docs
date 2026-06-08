# Install

Ordered bare-metal runbook to stand up the whole jaskier-os stack on a single host. Each service
repo carries its own deeper docs; "see <repo>" points there. Ports and service set: see
ARCHITECTURE.md.

## 1. Prerequisites

- A Linux host with root (or sudo) for the control-plane node.
- Packages: docker with the buildx plugin, git, curl, unzip, kubectl.
- Verify: `docker buildx version`, `git --version`, `kubectl version --client`.

## 2. Install k3s

Single control-plane node:

```
curl -sfL https://get.k3s.io | sh -
```

k3s ships its own kubectl; run cluster commands as `sudo k3s kubectl ...` (or copy
`/etc/rancher/k3s/k3s.yaml` to `~/.kube/config` to use a standalone `kubectl`).

## 3. In-cluster Docker registry

Run a persistent registry on the host, reachable as `localhost:5000`:

```
docker volume create registry-data
docker run -d --restart=always --name registry -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v registry-data:/var/lib/registry \
  registry:2
```

Images are pushed as `localhost:5000/<svc>:<tag>`; deployment manifests reference the same
`localhost:5000/<svc>:<tag>`.

## 4. Build images

For each service, build its own Dockerfile and push to the registry:

```
docker buildx build -f <Dockerfile> -t localhost:5000/<svc>:<tag> --push .
```

Buildable services: communicator, orchestrator, anthropic-stt, kokoro-tts, piper-tts,
teratts-tts, translator, ocr, transcriber, chat-history-agent, clickup-agent, reid-agent,
security-agent, vision-agent, pc-agent (jaskier-os); reid-worker, reid-db-handler, reid-analytics
(reid). transcriber and pc-agent are built but not cluster-deployed. Each repo's README has its
exact Dockerfile name and build args (e.g. reid-worker fetches model weights at build time).

External images, used as-is (no build): mongo:7, postgres:16-alpine,
ghcr.io/flaresolverr/flaresolverr, ghcr.io/remsky/kokoro-fastapi.

This step can be automated with a GitLab shell runner (executor=shell, tags `shell,docker`,
`run_untagged=true`, docker + buildx available) that builds + pushes on each push to `main`.

## 5. Namespaces

```
sudo k3s kubectl create namespace ai
sudo k3s kubectl create namespace recon
```

`ai` holds the assistant services + agents; `recon` holds the ReID pipeline.

## 6. Secrets and config

Create the Secrets each service expects (the shared API key, datastore credentials, provider
keys). Supply your own values:

```
sudo k3s kubectl -n ai create secret generic ai-secrets \
  --from-literal=API_KEY=<your-key> \
  --from-literal=ANTHROPIC_API_KEY=<your-key>
sudo k3s kubectl -n recon create secret generic reid-secrets \
  --from-literal=API_KEY=<your-key>
```

Each repo's `.env.example` lists the exact variables it needs; mirror those into the namespace
Secret/ConfigMap referenced by its Deployment.

## 7. Deploy services

Write a standard Kubernetes `Deployment` + `Service` per service (image
`localhost:5000/<svc>:<tag>`, the port from ARCHITECTURE.md, env from the Secret above) and apply
them into the right namespace:

```
sudo k3s kubectl apply -n ai    -f manifests/ai/
sudo k3s kubectl apply -n recon -f manifests/recon/
```

Deploy the external images (mongo:7, postgres:16-alpine, flaresolverr, kokoro-fastapi) as their
own Deployments + Services in the same way.

## 8. Expose externally

Expose the public entry points (orchestrator, and any HTTP service you need to reach) with either
a `NodePort` Service or an `Ingress`:

```
# simplest: NodePort
sudo k3s kubectl -n ai expose deployment orchestrator \
  --type=NodePort --port=10001 --name=orchestrator-ext
# or an Ingress object routing a hostname/path to the service ClusterIP
```

## 9. Verify

```
sudo k3s kubectl get pods -n ai
sudo k3s kubectl get pods -n recon
```

All pods should reach `Running`/`Ready`. Check a service's logs with
`sudo k3s kubectl logs -n ai deploy/<svc>` if one crash-loops.

## 10. Clients

Clients are not in the cluster: glasses, phone, desktop, and pc are built and deployed separately
to their devices, and the glasses firmware is flashed separately. See each client repo;
client-glasses has a `firmware/` directory with `fetch-os.sh` and flashing docs.
