# wiki/ — GitHub/GitLab Wiki content

This folder is **wiki-format Markdown**, not part of the MkDocs site under `docs/`. It is the
source for the project wiki, kept here so it lives next to the code and gets reviewed in normal
commits. It is meant to be **pushed to a wiki repository**, which is a separate git repo from the
project itself.

## Format conventions

- One file per page; the filename is the page title (`-` renders as a space, so
  `Phone-App.md` → "Phone App").
- Navigation is the hand-written `_Sidebar.md`; `_Footer.md` renders under every page. These
  two special pages are wiki-only (no effect anywhere else).
- Internal links use wiki syntax: `[[Architecture]]`, or `[[Phone App|Phone-App]]` to show a
  different label. This syntax works on **both** GitHub and GitLab wikis, so it survives the
  GitLab → GitHub mirror.
- Media is referenced with relative paths (e.g. `assets/phone-home.png`); commit the binaries
  into the wiki repo alongside the pages. Wikis don't support MkDocs `attr_list` sizing or
  `<video>` embeds — see [[Features]] for the supported snippets.

## Publishing

A wiki repo isn't the project repo. Once the GitHub repo exists (this project mirrors
GitLab → GitHub), its wiki lives at `https://github.com/<owner>/<repo>.wiki.git` (initialize it
by creating the first page once in the GitHub UI). Then publish the contents of this folder:

```bash
git clone https://github.com/<owner>/<repo>.wiki.git /tmp/wiki
cp -a wiki/. /tmp/wiki/
cd /tmp/wiki && git add -A && git commit -m "Sync wiki from main repo" && git push
```

The same procedure targets a GitLab wiki at `git@10.29.71.1:jaskier-os/docs.wiki.git` (or the
relevant project) if you want it live on GitLab before the mirror.

## Pages

| File              | Page          |
| ----------------- | ------------- |
| `Home.md`         | Landing + service/port tables |
| `Architecture.md` | Ports, service map, data flow, build/deploy |
| `Installation.md` | Bare-metal k3s runbook |
| `Features.md`     | Glasses + phone features (consumer-facing) |
| `_Sidebar.md`     | Navigation (wiki-only) |
| `_Footer.md`      | Footer (wiki-only) |
