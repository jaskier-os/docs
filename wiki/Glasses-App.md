# Glasses App

The Rokid AR glasses listener app (`jaskier-os/client-glasses`, Kotlin) plus its firmware
tooling. The glasses do not talk to the backend directly — they pair with the phone over
Bluetooth and relay through it. Capture audio, take photos, drive the HUD, and answer the
assistant hands-free.

<!-- media: hero shot through the glasses HUD -> assets/glasses-hud.png -->

## Wake word & voice

Hands-free wake word starts a voice turn; captured audio is relayed via the phone to the
backend for transcription. English replies route to Kokoro TTS, Russian to Tera TTS (GLaDOS
voice).

<!-- media: clip of a hands-free voice turn -> assets/glasses-voice.mp4 -->

## Touchpad gestures

The temple touchpad maps to key events:

| Gesture          | Action                                    |
| ---------------- | ----------------------------------------- |
| Tap              | Select / confirm                          |
| Hold (~500 ms)   | Open AI chat                              |
| Scroll fwd/back  | Navigate lists / scroll                   |

<!-- media: clip demonstrating tap / hold / scroll -> assets/glasses-touchpad.mp4 -->

## Camera

On-demand photo capture for the Vision Agent (image analysis) and ReID. JPEGs are pixel-
rotated to the correct orientation before encoding.

<!-- media: example captured frame -> assets/glasses-capture.jpg -->

## HUD output

Assistant replies and status render on the in-lens display. Audio playback ducks local
media and compensates AudioTrack volume so the response stays audible.

<!-- media: screenshot of a rendered HUD reply -> assets/glasses-hud-reply.png -->

## Fold / wear detection

A fold/unfold signal (`vendor.rkd.glasses.is_spread`) gates audio handoff and power
behaviour: unfolded = worn/active, folded = idle. Used to manage A2DP routing and suspend.

## Status LED

The RGBW indicator surfaces state (e.g. charging / battery). The on-device daemon owns the
LED via sysfs; the app arms charge-indicator behaviour through a flag file.

## OSINT lookups (optional)

Like the phone, the assistant-driven OSINT lookup capability on the glasses is gated by
`ENABLE_REID_OSINT=true` (env or `local.properties`). Disabled by default. Core face
re-identification is unaffected.

> **Note**
> Pairs with the phone app (`ENABLE_REID_OSINT`) and the `reid-analytics` backend
> (`ENABLE_OSINT`). See each repo's CLAUDE.md.

## Firmware tooling

The repo also carries glasses firmware tooling (root/recovery, stock-image helpers). Flash
procedures and the enter-EDL + QDL flow are documented in the repo's own scripts and
CLAUDE.md — not here. **Never flash the active A/B slot or patch vbmeta.**
