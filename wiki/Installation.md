# Installation

Ordered bare-metal runbook to stand up the whole jaskier-os stack on a single host. Each service
repo carries its own deeper docs; "see <repo>" points there. Ports and service set: see
[[Architecture]].

## Deployment order

Bring the system up in this sequence, verifying each layer before moving on — it makes failures
easy to localize (a broken layer can't be masked by a later one):

1. **Clients first** — flash the glasses, install the phone app, and pair them. (§10)
2. **Orchestrator** — deploy it and confirm the phone connects to it. (§11)
3. **Communicator** — deploy it, confirm it connects to the orchestrator, and test a real AI
   conversation from the phone/glasses. (§12)
4. **Agents** — deploy them, verify each registers with the orchestrator, and test an agentic
   capability end to end. (§13)
5. **Everything else** — the remaining services (TTS, OCR, translator, ReID, datastores). (§14)

Sections 1–9 below are the cluster groundwork (k3s, registry, images, namespaces, secrets) that
the staged rollout in §10–14 builds on.

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
teratts-tts, translator, ocr, transcriber, chat-history-agent, clickup-agent,
vision-agent, pc-agent (jaskier-os); reid-worker, reid-db-handler, reid-analytics
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
`localhost:5000/<svc>:<tag>`, the port from [[Architecture]], env from the Secret above) and apply
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

## 10. Clients (deploy first)

Clients are not in the cluster — they run on the devices. Set them up before any backend so you
have something to verify the backend against.

### a) Flash the glasses

The glasses firmware is flashed separately, before the app. Tooling and docs live in
`client-glasses/firmware/`:

- `fetch-os.sh` — downloads the stock OS images (not committed; fetched on demand).
- `README.md` — the flashing walkthrough; `OVERLAY-README.md` covers the custom overlay,
  `PSOC-TOUCHPAD-BOOTLOADER.md` the touchpad firmware.
- `scripts/flash.sh` — the actual flash driver; `rawprogram_*.xml` are the partition maps
  (super4, dtbo, stock recovery). `root-firmware.sh` roots the device.

Follow `firmware/README.md` for the enter-EDL + QDL flash procedure. Never flash the active A/B
slot or patch vbmeta.

### b) Install the phone app

Build and install with the deploy script (do NOT use a plain `adb install`):

```
client-phone/scripts/deploy-to-phone.sh
```

It builds the `productionDebug` flavor and, crucially, **grants runtime permissions a normal
install misses** — e.g. it re-grants the notification-listener access that MIUI/POCO silently
revokes on update (otherwise Telegram/notification features break with no obvious error). If it
warns it couldn't grant one, enable it by hand in Settings.

### c) Pair the glasses with the phone

1. With the glasses **folded**, press the function button **3 times rapidly** until the **blue
   LED** turns on (pairing mode).
2. On the phone: **Glasses tab -> Settings -> Pair mode**.
3. Wait for the two devices to find and connect to each other — up to 1-2 minutes.

Once paired, the glasses relay through the phone (they don't talk to the backend directly).

## 11. Orchestrator

Deploy the orchestrator first among the backend services (build + manifest per §4-§8; expose it
per §8 so the phone can reach it).

**Verify:** point the phone at the orchestrator URL and confirm it connects (the phone shows a
live connection; `sudo k3s kubectl logs -n ai deploy/orchestrator` shows the device session). Do
not proceed until the phone is connected.

## 12. Communicator

Deploy the communicator (the LLM gateway).

**Verify:** confirm it reaches the orchestrator, then **test a real AI conversation** from the
phone or glasses — send a prompt and confirm you get a model response back end to end. If the
turn completes, the core path (device -> orchestrator -> communicator -> Claude -> back) works.

## 13. Agents

Deploy the agents (chat-history, clickup, vision, security, web-search, reid-agent, etc.).

**Verify:** each agent should register with the orchestrator on startup
(`kubectl logs -n ai deploy/orchestrator` shows the agent manifest registering; the agent's own
logs show the WS connection). Then **test an agentic capability** — issue a request that routes
to an agent (e.g. a web search or a ClickUp action) and confirm the agent handles it and the
result comes back to the device.

## 14. Everything else

Deploy the remaining services: the TTS engines (kokoro/teratts and any others in use), OCR,
translator, the ReID pipeline (reid-worker, reid-db-handler, reid-analytics) in the `recon`
namespace, and the datastores/external images (mongo, postgres, flaresolverr). Verify each per
§9. At this point the full stack is up.
