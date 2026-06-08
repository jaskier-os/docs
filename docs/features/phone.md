# Phone

The Android companion app (`jaskier-os/client-phone`, package `com.repository.listener`).
It is the user's main control surface: it runs the assistant conversation, hosts the ReID
dashboard, and acts as the relay/sideloader for the glasses APK. Default build flavor is
`productionDebug`.

<!-- media: hero shot of the phone app home screen -> assets/img/phone-home.png -->

## Assistant chat

Voice and text conversation with the orchestrator over WebSocket. Markdown replies are
rendered (Markwon); the app handles streaming responses and multi-turn context.

<!-- media: clip of a voice turn end-to-end -> assets/video/phone-chat.mp4 -->

## Voice capture & wake word

On-device VAD (Silero) + wake word (openWakeWord) via ONNX Runtime, with Whisper.cpp
available natively. Audio streams to the backend for transcription/translation.

<!-- media: clip showing wake-word trigger -> assets/video/phone-wakeword.mp4 -->

## Audio streaming (WebRTC)

Low-latency audio uses WebRTC. TURN relay is optional (`TURN_URL`); with it blank the app
falls back to STUN-only.

## Maps & navigation

Optional in-app maps: Google Maps (`GOOGLE_MAPS_API_KEY`) and Yandex MapKit
(`MAPKIT_API_KEY`) in the `:navigation` module. Both degrade gracefully when the key is
absent.

<!-- media: screenshot of the navigation view -> assets/img/phone-nav.png -->

## ReID dashboard

Browse recognized people sourced from the ReID pipeline.

<!-- media: screenshot of the people list -> assets/img/phone-reid-list.png -->

### Region-specific tabs (optional)

Hidden by default. Set `ENABLE_REID_RU_TABS=true` (env or `local.properties`) to show the
**Phone Numbers** sub-tab in the ReID screen and the **Intel** tab in person detail.

### OSINT lookups (optional)

The assistant-driven OSINT lookup tool (`lookup_person_info`: person-info / phone-number /
sherlock intel) is gated by `ENABLE_REID_OSINT=true`. Core face re-identification
(`identify_person`) is **not** gated by this flag and always works.

!!! note "Cross-component flags"
    These toggles pair with backend switches in `reid-analytics` (`ENABLE_OSINT`) and the
    glasses app (`ENABLE_REID_OSINT`). See each repo's CLAUDE.md.

## Glasses relay / sideloader

The phone hosts the Rokid glasses APK relay and sideloader, and a direct RFCOMM message
relay to the glasses (length-prefixed framed). The glasses connect to the backend *through*
the phone.

<!-- media: screenshot of the relay / pairing screen -> assets/img/phone-relay.png -->

## Build-time configuration

| Key                       | Default                          | Effect                                              |
| ------------------------- | -------------------------------- | --------------------------------------------------- |
| `LOCAL_ORCHESTRATOR_URL`  | `ws://127.0.0.1:10001/ws/device` | Backend WS URL for the `local` flavor               |
| `PRODUCTION_ORCHESTRATOR_URL` | placeholder `wss://...:8443` | Backend WS URL for the `production` flavor          |
| `GOOGLE_MAPS_API_KEY`     | empty                            | Google map rendering                                |
| `MAPKIT_API_KEY`          | empty                            | Yandex MapKit                                       |
| `TURN_URL` / `TURN_USERNAME` / `TURN_PASSWORD` | empty       | WebRTC TURN relay (else STUN-only)                  |
| `ENABLE_REID_RU_TABS`     | `false`                          | Phone Numbers sub-tab + person Intel tab            |
| `ENABLE_REID_OSINT`       | `false`                          | Assistant OSINT lookup tool                         |

All values resolve env var → `local.properties` → safe placeholder default. Nothing real is
committed; see `local.properties.example` in the repo.
