# jaskier-os

Canonical whole-system documentation for the jaskier-os stack: a voice/vision AI assistant
platform built around a central orchestrator that classifies intent, routes to specialized
agents and speech services, and talks to Anthropic Claude through a single LLM gateway. It runs
as containerized services on a single-node k3s cluster, deployed via GitLab CI plus Flux GitOps.
The codebase was split from a monorepo into 30 standalone repos; this repo documents how they fit
together.

## Architecture sketch

```
glasses / phone / desktop (voice + vision devices)
  -> orchestrator (intent classifier + router + session state, port 10001)
       -> agents: web-search, vision, reid, chat-history, clickup, security
       -> speech services: STT (anthropic-stt, transcriber), TTS (kokoro/piper/...),
          translator, ocr
       -> communicator (LLM gateway, port 10000) -> Anthropic Claude

separate ReID pipeline:
  cameras/glasses -> reid-worker -> reid-db-handler (only DB owner, port 3001)
                  -> reid-analytics (aggregation + dashboard, port 3400)
```

## Project index

Ports are from the orchestrator port table (see ARCHITECTURE.md). Services with no network port
(clients, the deploy catalog) show "-".

| Project | Repo (group/name) | Purpose | Port |
|---------|-------------------|---------|------|
| Orchestrator | jaskier-os/orchestrator | Central router/classifier/dispatcher; owns @orchestrator/sdk | 10001 |
| Communicator | jaskier-os/communicator | LLM API gateway, OpenAI-compatible -> Anthropic Claude | 10000 |
| Anthropic STT | jaskier-os/anthropic-stt | Speech-to-text via Anthropic | 10016 |
| Kokoro TTS | jaskier-os/kokoro-tts | Kokoro text-to-speech | 10007 |
| Piper TTS | jaskier-os/piper-tts | Piper text-to-speech (lightweight) | 10013 |
| Tera TTS | jaskier-os/teratts-tts | Tera text-to-speech | - |
| Silero TTS | jaskier-os/silero-tts | Silero text-to-speech (built, not cluster-deployed) | - |
| eSpeech TTS | jaskier-os/espeech-tts | eSpeech text-to-speech (built, not cluster-deployed) | - |
| Translator | jaskier-os/translator | NLLB-200 multilingual translation | 10015 |
| OCR | jaskier-os/ocr | OCR / text extraction from images | 10006 |
| Context Mode | jaskier-os/context-mode | Context-window offloading tool (PC-side, not cluster-deployed) | - |
| Transcriber | jaskier-os/transcriber | Audio transcription (faster-whisper; built, not cluster-deployed) | 10003 |
| Chat History Agent | jaskier-os/chat-history-agent | Conversation history store (WS agent + REST API) | 10014 |
| ClickUp Agent | jaskier-os/clickup-agent | ClickUp integration (MCP + agentic wrapper) | 10012 |
| ReID Agent | jaskier-os/reid-agent | Bridges reid-worker capabilities to the orchestrator | 10011 |
| Security Agent | jaskier-os/security-agent | Network/system security tools agent | 10009 |
| Vision Agent | jaskier-os/vision-agent | Image analysis; can delegate to web-search | 10005 |
| Web Search Agent | jaskier-os/web-search-agent | Web/academic search MCP server + agentic wrapper | 10002 |
| Obsidian Agent | jaskier-os/obsidian-agent | Knowledge assistant (PC-side, not cluster-deployed) | 10010 |
| PC Agent | jaskier-os/pc-agent | NL -> shell with safety + remote-control (PC-side, not cluster-deployed) | 10004 |
| Client PC | jaskier-os/client-pc | PC client | - |
| Client Desktop | jaskier-os/client-desktop | Voice listener (Python + PyQt6 + Vosk + faster-whisper) | - |
| Client Glasses | jaskier-os/client-glasses | Rokid AR glasses listener app (Kotlin) + firmware | - |
| Client Phone | jaskier-os/client-phone | Android companion app (Kotlin) + glasses APK relay | - |
| Client Glasses Mouse | jaskier-os/client-glasses-mouse | Glasses pointer/mouse input client | - |
| ReID DB Handler | reid/reid-db-handler | Only component allowed to touch the ReID/FAISS database | 3001 |
| ReID Worker | reid/reid-worker | Camera feed -> person/face/gait recognition; posts to reid-db-handler | - |
| ReID Analytics | reid/reid-analytics | Aggregates reid-db-handler data; recognized-people dashboard | 3400 |
| Deploy | infrastructure/deploy | k8s GitOps catalog (private; holds real secrets/TLS) | - |
| Obsidian Chat | obsidian/obsidian-chat | Obsidian AI chat plugin (RAG, tools, agentic) | - |
| MongoDB | (external image mongo:7) | Orchestrator session/chat store | - |
| PostgreSQL | (external image postgres:16-alpine) | ReID relational store | - |
| FlareSolverr | (external ghcr image) | Cloudflare/JS challenge solver for web-search | - |
| Kokoro FastAPI | (external ghcr.io/remsky/kokoro-fastapi) | Kokoro TTS serving image | - |
| API key gate | (external nginx:alpine) | Edge API-key auth proxy | - |
| Ingress | (Traefik, bundled with k3s) | Cluster ingress | - |

## Pointers

- Stand up the whole stack: see INSTALL.md.
- Architecture + ports: see ARCHITECTURE.md.
- Per-project detail: each repo's own README / CLAUDE.md.
