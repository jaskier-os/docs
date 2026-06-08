# Architecture

Canonical system reference for the jaskier-os stack. Port allocation and service map are lifted
from the orchestrator repo's "System architecture (all repos)" section (jaskier-os/orchestrator
CLAUDE.md), the architectural source of truth.

## Port allocation

| Port  | Service                          |
|-------|----------------------------------|
| 10000 | Communicator (LLM API gateway)   |
| 10001 | Orchestrator (HTTP + WebSocket)  |
| 10002 | Web Search MCP server            |
| 10003 | Transcriber                      |
| 10004 | PC Agent (health)                |
| 10005 | Vision Agent (health)            |
| 10006 | OCR Service                      |
| 10007 | Kokoro TTS                       |
| 10009 | Security Agent (health)          |
| 10010 | Obsidian Agent (health)          |
| 10011 | ReID Agent (health)              |
| 10012 | ClickUp Agent (health)           |
| 10013 | Piper TTS                        |
| 10014 | Chat History Agent (REST API)    |
| 10015 | Translator (NLLB-200)            |
| 10016 | Anthropic STT                    |
| 3001  | ReID DB Handler                  |
| 3400  | ReID Analytics backend           |

## Services

### Backends
- Orchestrator (10001) -- central router; classifies intent (LLM call via Communicator),
  dispatches to agents, holds session/chat state in MongoDB, streams over HTTP + WebSocket. Owns
  @orchestrator/sdk consumed by every agent.
- Communicator (10000) -- LLM API gateway (Koa). OpenAI-compatible endpoint translated to
  Anthropic Claude; streaming, multimodal.

### Speech / vision services
- Anthropic STT (10016) -- speech-to-text.
- Transcriber (10003) -- audio transcription (FastAPI + faster-whisper). Built, not cluster-deployed.
- Kokoro TTS (10007), Piper TTS (10013) -- text-to-speech (cluster-deployed).
- Tera / Silero / eSpeech TTS -- additional TTS engines; silero-tts and espeech-tts are built but
  not cluster-deployed.
- Translator (10015) -- NLLB-200 multilingual translation (FastAPI).
- OCR (10006) -- text extraction from images (FastAPI).

### Agents
Each agent is its own repo, extends BaseAgent from @orchestrator/sdk, connects outbound to the
orchestrator over WebSocket, and registers a manifest. No orchestrator redeploy is needed to add one.
- Web Search Agent (10002) -- web/academic search, URL reading, reverse image search (MCP server + wrapper).
- Vision Agent (10005) -- image analysis; can delegate to web-search.
- ReID Agent (10011) -- bridges reid-worker capabilities to the orchestrator.
- Chat History Agent (10014) -- conversation history (WS agent + standalone REST API).
- ClickUp Agent (10012) -- ClickUp integration.
- Security Agent (10009) -- network/system security tools.
- PC Agent (10004) -- NL -> shell with safety validation + remote-control sessions. PC-side, not cluster-deployed.
- Obsidian Agent (10010) -- local knowledge assistant (vault CRUD, RAG, code exec). PC-side, not cluster-deployed.

### Clients
Build and deploy to devices, not the cluster.
- Client Glasses -- Rokid AR glasses listener (Kotlin); connects via the phone relay; includes firmware.
- Client Phone -- Android companion (Kotlin); also hosts the glasses APK relay/sideloader.
- Client Desktop -- voice listener (Python + PyQt6 + Vosk wake word + faster-whisper).
- Client PC -- PC client.
- Client Glasses Mouse -- glasses pointer/mouse input client.

### ReID pipeline (parallel subsystem)
- ReID Worker -- camera feed -> person/face/gait recognition (YOLOv8 + SCRFD + ArcFace ONNX/FAISS,
  OpenGait); posts new data to reid-db-handler.
- ReID DB Handler (3001) -- Koa API; the only component allowed to touch the ReID/FAISS database.
  Everything goes through this API; nothing connects to the DB directly.
- ReID Analytics (3400) -- aggregates reid-db-handler data; recognized-people dashboard.

### Obsidian
- Obsidian Chat -- Obsidian AI chat plugin (RAG, tools, agentic).

### Infrastructure
- Deploy (infrastructure/deploy) -- Kubernetes manifests (apps/, clusters/, infrastructure/);
  GitOps source of truth. Private; holds real secret values and TLS material.
- External in-cluster images used as-is: mongo:7 (orchestrator store), postgres:16-alpine (ReID),
  flaresolverr (ghcr), ghcr.io/remsky/kokoro-fastapi, api-key-gate (nginx:alpine), Traefik ingress.

## Data flow

1. A device (glasses/phone/desktop) sends a request to the orchestrator (10001) over HTTP/WS.
2. The orchestrator classifies intent via an LLM call through the Communicator (10000), using the
   manifests of registered agents.
3. It dispatches to the chosen agent over WebSocket. An agent may return `needs_input` (asking the
   device for a photo, audio, geolocation, etc.) or `needs_agent` (delegating to another agent).
4. Agents call the Communicator for LLM work; the orchestrator routes speech/vision tasks directly
   to STT, transcriber, TTS, translator, and OCR.
5. The Communicator forwards LLM calls to the Anthropic Claude API.
6. The orchestrator aggregates/formats the response per device type and streams it back.
7. ReID is a separate path: cameras/glasses -> reid-worker -> reid-db-handler API -> reid-analytics.

## Deploy flow

```
git push to main (a service repo)
  -> GitLab shell runner: docker buildx build -f <Dockerfile>
       -t localhost:5000/<svc>:<short_sha> -t localhost:5000/<svc>:latest --push .
  -> in-cluster registry at localhost:5000 (registry:2)
  -> CI SSH-clones infrastructure/deploy, sed-bumps the image tag in apps/**/deployment.yaml,
     commits + pushes
  -> Flux (FluxCD) reconciles infrastructure/deploy onto the k3s cluster (prune=true)
```

Flux Kustomizations run `infrastructure` first (namespaces ai + recon, secrets, TLS, backup) then
`apps` (apps/ai + apps/recon).

## Tech-stack summary

| Area               | Choice |
|--------------------|--------|
| Languages          | JavaScript ES modules (Node services), Python (clients, ML, TTS/STT/OCR/translation), Kotlin (phone/glasses), TypeScript (obsidian plugins) |
| Server frameworks  | Koa (orchestrator, communicator, reid-db-handler), Express (MCP servers), FastAPI (transcriber, ocr, translator) |
| Agent connectivity | WebSocket -- agents connect outbound, orchestrator pushes tasks; no message broker |
| Intent classifier  | Claude via Communicator (LLM-based, uses agent manifests) |
| LLM gateway        | Communicator (OpenAI API -> Anthropic Claude translation) |
| Session/chat state | MongoDB (orchestrator) |
| ReID models        | YOLOv8, SCRFD, ArcFace (ONNX), OpenGait; FAISS for matching |
| Auth               | Shared API key (Bearer token or x-api-key header) |
| Data stores        | MongoDB (orchestrator), PostgreSQL + FAISS (ReID) |
| Cluster            | k3s single control-plane node; Traefik ingress |
| Registry           | In-cluster registry:2 at localhost:5000 |
| CI/CD              | GitLab CI buildx --push; Flux GitOps via infrastructure/deploy |
