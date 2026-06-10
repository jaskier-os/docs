# Features

Behavioural documentation for the client apps — what they do from the user's side, as
opposed to the service/port view in [[Architecture]]. This is the place to describe
end-to-end flows and show them with screenshots and short clips.

- **[[Phone App]]** — the Android companion app (POCO M7 Pro). Hosts the assistant UI,
  the ReID dashboard, and the glasses relay/sideloader.
- **[[Glasses App]]** — the Rokid AR glasses listener: wake word, audio capture,
  touchpad gestures, HUD output.

## Adding media

GitHub/GitLab wikis store binary assets in the wiki repo itself. Commit images/clips
alongside the pages (e.g. an `assets/` subfolder in the wiki repo) and reference them with a
relative path, or paste an image into the web editor to have it uploaded automatically.

**Image:**

```markdown
![Assistant chat screen](https://raw.githubusercontent.com/wiki/jaskier-os/docs/assets/phone-chat.png)
```

**Video** — wikis don't embed `<video>` players; upload the clip and link it:

```markdown
[Wake-word demo (mp4)](https://raw.githubusercontent.com/wiki/jaskier-os/docs/assets/phone-wakeword.mp4)
```

> **Tip**
> Put a one-line italic caption under each image/clip so the page reads on its own:
> *Tapping the mic starts a streaming voice turn.*

Each feature page has placeholder slots (`<!-- media: ... -->`) marking where a screenshot or
clip belongs. Replace the comment with a snippet above once the file is committed to the wiki.
