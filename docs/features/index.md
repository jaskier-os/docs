# Features

Behavioural documentation for the client apps — what they do from the user's side, as
opposed to the service/port view in [Architecture](../ARCHITECTURE.md). This is the place
to describe end-to-end flows and show them with screenshots and short clips.

- **[Phone](phone.md)** — the Android companion app (POCO M7 Pro). Hosts the assistant UI,
  the ReID dashboard, and the glasses relay/sideloader.
- **[Glasses](glasses.md)** — the Rokid AR glasses listener: wake word, audio capture,
  touchpad gestures, HUD output.

## Adding media

Drop files under `assets/` and reference them with a path relative to the page:

- Images: `assets/img/<name>.png` (or `.jpg`). Keep them reasonably sized (web, not raw
  camera dumps).
- Videos: `assets/video/<name>.mp4`. H.264/AAC `.mp4` plays inline in every browser.

**Image** (Markdown, with optional width via `attr_list`):

```markdown
![Assistant chat screen](../assets/img/phone-chat.png){ width="320" }
```

**Video** (inline HTML — `md_in_html` is enabled, so this renders):

```html
<video controls width="360">
  <source src="../assets/video/phone-wakeword.mp4" type="video/mp4">
</video>
```

!!! tip "Captions"
    Put a one-line italic caption under each image/video so the page reads on its own:
    `*Tapping the mic starts a streaming voice turn.*`

Each feature page below has placeholder slots (`<!-- media: ... -->`) marking where a
screenshot or clip belongs. Replace the comment with the snippet above once the file is in
`assets/`.
