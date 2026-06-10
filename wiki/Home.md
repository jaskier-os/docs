# jaskier-os

A voice/vision AI assistant platform built around a central orchestrator that classifies
intent, routes to specialized agents and speech services, and talks to Anthropic Claude
through a single LLM gateway. It runs as containerized services on a single-node k3s cluster.
The codebase was split from a monorepo into standalone repos; this wiki documents how they
fit together.

## Where to start

- **[[Architecture]]** — port allocation, service map, data flow, build + deploy.
- **[[Installation]]** — stand up the whole stack on bare metal.
- **[[Features]]** — what the phone and glasses clients actually do, with screenshots and clips.

## Backend services

| Project       | Repo                     | Purpose                                                           | Port  |
| ------------- | ------------------------ | ----------------------------------------------------------------- | ----- |
| Orchestrator  | jaskier-os/orchestrator  | Central router/classifier/dispatcher; owns @orchestrator/sdk      | 10001 |
| Communicator  | jaskier-os/communicator  | LLM API gateway, OpenAI-compatible -> Anthropic Claude            | 10000 |
| Anthropic STT | jaskier-os/anthropic-stt | Speech-to-text via Anthropic                                      | 10016 |
| Transcriber   | jaskier-os/transcriber   | Audio transcription (faster-whisper); built, not cluster-deployed | 10003 |
| Kokoro TTS    | jaskier-os/kokoro-tts    | Text-to-speech (English)                                          | 10007 |
| Tera TTS      | jaskier-os/teratts-tts   | Text-to-speech (Russian; GLaDOS voice)                            | 10018 |
| Translator    | jaskier-os/translator    | NLLB-200 multilingual translation                                 | 10015 |
| OCR           | jaskier-os/ocr           | OCR / text extraction from images                                 | 10006 |

## Agents

| Project            | Repo                          | Purpose                                                               | Port  |
| ------------------ | ----------------------------- | --------------------------------------------------------------------- | ----- |
| Chat History Agent | jaskier-os/chat-history-agent | Conversation history store (WS agent + REST API)                      | 10014 |
| ClickUp Agent      | jaskier-os/clickup-agent      | ClickUp integration (MCP + agentic wrapper)                           | 10012 |
| Vision Agent       | jaskier-os/vision-agent       | Image analysis                                                        | 10005 |
| PC Agent           | jaskier-os/pc-agent           | NL -> shell with safety + remote control; built, not cluster-deployed | 10004 |

## ReID

| Project         | Repo                 | Purpose                                                               | Port |
| --------------- | -------------------- | --------------------------------------------------------------------- | ---- |
| ReID Worker     | reid/reid-worker     | Camera feed -> person/face/gait recognition; posts to reid-db-handler | -    |
| ReID DB Handler | reid/reid-db-handler | Only component allowed to touch the ReID/FAISS database               | 3001 |
| ReID Analytics  | reid/reid-analytics  | Aggregates reid-db-handler data; recognized-people dashboard          | 3400 |

## Clients

| Project        | Repo                      | Purpose                                            | Port |
| -------------- | ------------------------- | -------------------------------------------------- | ---- |
| Client Desktop | jaskier-os/client-desktop | Desktop relay client (Python + PyQt6)              | -    |
| Client Glasses | jaskier-os/client-glasses | Rokid AR glasses listener app (Kotlin) + firmware  | -    |
| Client Phone   | jaskier-os/client-phone   | Android companion app (Kotlin) + glasses APK relay | -    |

## Infrastructure

| Component    | Image                             | Purpose                         | Port |
| ------------ | --------------------------------- | ------------------------------- | ---- |
| MongoDB      | mongo:7                           | Orchestrator session/chat store | -    |
| PostgreSQL   | postgres:16-alpine                | ReID relational store           | -    |
| FlareSolverr | ghcr.io/flaresolverr/flaresolverr | Cloudflare/JS challenge solver  | -    |
