# Architecture

Canonical system reference for the jaskier-os stack: port allocation, service map, data flow,
and how the stack is built and deployed.

## Port allocation

| Port  | Service                          |
|-------|----------------------------------|
| 10000 | Communicator (LLM API gateway)   |
| 10001 | Orchestrator (HTTP + WebSocket)  |
| 10003 | Transcriber                      |
| 10004 | PC Agent (health)                |
| 10005 | Vision Agent (health)            |
| 10006 | OCR Service                      |
| 10007 | Kokoro TTS                       |
| 10009 | Security Agent (health)          |
| 10012 | ClickUp Agent (health)           |
| 10013 | Piper TTS                        |
| 10014 | Chat History Agent (REST API)    |
| 10015 | Translator (NLLB-200)            |
| 10016 | Anthropic STT                    |
| 10018 | Tera TTS                         |
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
- Kokoro TTS (10007) -- text-to-speech; runs the ghcr.io/remsky/kokoro-fastapi image.
- Piper TTS (10013), Tera TTS (10018) -- text-to-speech.
- Translator (10015) -- NLLB-200 multilingual translation (FastAPI).
- OCR (10006) -- text extraction from images (FastAPI).

### Agents
Each agent is its own repo, extends BaseAgent from @orchestrator/sdk, connects outbound to the
orchestrator over WebSocket, and registers a manifest. No orchestrator redeploy is needed to add one.
- Vision Agent (10005) -- image analysis.
- Chat History Agent (10014) -- conversation history (WS agent + standalone REST API).
- ClickUp Agent (10012) -- ClickUp integration.
- Security Agent (10009) -- network/system security tools.
- PC Agent (10004) -- NL -> shell with safety validation + remote-control sessions. Built, not cluster-deployed.

### Clients
Build and deploy to devices, not the cluster.
- Client Glasses -- Rokid AR glasses listener (Kotlin); connects via the phone relay; includes firmware.
- Client Phone -- Android companion (Kotlin); also hosts the glasses APK relay/sideloader.
- Client Desktop -- desktop relay client (Python + PyQt6).

### ReID pipeline (parallel subsystem)
- ReID Worker -- camera feed -> person/face/gait recognition (YOLOv8 + SCRFD + ArcFace ONNX/FAISS,
  OpenGait); posts new data to reid-db-handler.
- ReID DB Handler (3001) -- Koa API; the only component allowed to touch the ReID/FAISS database.
  Everything goes through this API; nothing connects to the DB directly.
- ReID Analytics (3400) -- aggregates reid-db-handler data; recognized-people dashboard.

### Infrastructure (external in-cluster images, used as-is)
- mongo:7 -- orchestrator session/chat store.
- postgres:16-alpine -- ReID relational store.
- ghcr.io/flaresolverr/flaresolverr -- Cloudflare/JS challenge solver.

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

## Build + deploy flow

Each service builds its own image and is deployed with standard Kubernetes manifests.

```
build:  docker buildx build -f <Dockerfile> \
          -t localhost:5000/<svc>:<tag> --push .
        -> in-cluster registry at localhost:5000 (registry:2)

deploy: kubectl apply -f <svc>/   (Deployment + Service per service,
          image localhost:5000/<svc>:<tag>, into namespace ai or recon)
```

Image builds can be automated by a GitLab shell runner on push to main. See INSTALL.md for the
full bare-metal procedure. Namespaces: `ai` (assistant services + agents) and `recon` (ReID).

## Tech-stack summary

| Area               | Choice |
|--------------------|--------|
| Languages          | JavaScript ES modules (Node services), Python (clients, ML, TTS/STT/OCR/translation), Kotlin (phone/glasses) |
| Server frameworks  | Koa (orchestrator, communicator, reid-db-handler), Express (MCP servers), FastAPI (transcriber, ocr, translator) |
| Agent connectivity | WebSocket -- agents connect outbound, orchestrator pushes tasks; no message broker |
| Intent classifier  | Claude via Communicator (LLM-based, uses agent manifests) |
| LLM gateway        | Communicator (OpenAI API -> Anthropic Claude translation) |
| Session/chat state | MongoDB (orchestrator) |
| ReID models        | YOLOv8, SCRFD, ArcFace (ONNX), OpenGait; FAISS for matching |
| Auth               | Shared API key (Bearer token or x-api-key header) |
| Data stores        | MongoDB (orchestrator), PostgreSQL + FAISS (ReID) |
| Cluster            | k3s single control-plane node |
| Registry           | In-cluster registry:2 at localhost:5000 |
| CI/CD              | GitLab CI buildx --push; deploy via kubectl apply |
