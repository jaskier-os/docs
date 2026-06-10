#!/usr/bin/env bash
# Two-way sync between GitLab (canonical) and GitHub for this repo.
# Runs in GitLab CI (shell runner). Idempotent: equal SHAs -> no-op.
#
# Behaviour:
#   - github == gitlab            -> nothing to do.
#   - gitlab ahead (github anc.)  -> fast-forward github to gitlab.
#   - github ahead (gitlab anc.)  -> fast-forward gitlab to github.
#   - diverged, clean merge       -> merge github into gitlab, push BOTH.
#   - diverged, conflict          -> open a GitHub PR (sync/from-gitlab-<sha>),
#                                    user resolves on GitHub; merge flows back next run.
#
# Required env (GitLab CI variables):
#   GITHUB_TOKEN       - push + PR API on github.com/jaskier-os/docs
#   GITLAB_PUSH_TOKEN  - push back to this GitLab project
#   CI_SERVER_HOST, CI_PROJECT_PATH, CI_DEFAULT_BRANCH - provided by GitLab CI
set -euo pipefail

BRANCH="${CI_DEFAULT_BRANCH:-main}"
GH_REPO="jaskier-os/docs"
GH_OWNER="jaskier-os"
GL_HOST="${CI_SERVER_HOST:-10.29.71.1:4443}"
GL_PATH="${CI_PROJECT_PATH:-jaskier-os/docs}"

export GIT_SSL_NO_VERIFY=1   # self-signed GitLab
git config --global user.email "sync-bot@jaskier-os"
git config --global user.name  "gitlab-github-sync"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
git clone -q "https://oauth2:${GITLAB_PUSH_TOKEN}@${GL_HOST}/${GL_PATH}.git" "$work"
cd "$work"
git remote add github "https://x-access-token:${GITHUB_TOKEN}@github.com/${GH_REPO}.git"
git fetch -q origin "$BRANCH"
git fetch -q github "$BRANCH"

GL="$(git rev-parse "origin/${BRANCH}")"
GH="$(git rev-parse "github/${BRANCH}")"
echo "gitlab=$GL  github=$GH"

if [ "$GL" = "$GH" ]; then
  echo "in sync; nothing to do."; exit 0
fi

git checkout -q -B "$BRANCH" "origin/${BRANCH}"

if git merge-base --is-ancestor "$GH" "$GL"; then
  echo "gitlab ahead -> fast-forward github."
  git push -q github "${BRANCH}:${BRANCH}"
  echo "github updated."; exit 0
fi

if git merge-base --is-ancestor "$GL" "$GH"; then
  echo "github ahead -> fast-forward gitlab."
  git merge -q --ff-only "github/${BRANCH}"
  git push -q origin "${BRANCH}:${BRANCH}"
  echo "gitlab updated."; exit 0
fi

echo "diverged -> attempting merge of github into gitlab."
if git merge -q --no-edit "github/${BRANCH}"; then
  echo "clean merge; pushing both."
  git push -q origin "${BRANCH}:${BRANCH}"
  git push -q github "${BRANCH}:${BRANCH}"
  echo "both in sync."; exit 0
fi

echo "merge conflict -> opening GitHub PR for resolution."
git merge --abort
PRB="sync/from-gitlab-$(git rev-parse --short origin/${BRANCH})"
git checkout -q -B "$PRB" "origin/${BRANCH}"
git push -q -f github "${PRB}:${PRB}"

api="https://api.github.com/repos/${GH_REPO}"
# Skip if an open PR already exists for this head.
existing="$(curl -fsS -H "Authorization: token ${GITHUB_TOKEN}" \
  "${api}/pulls?state=open&head=${GH_OWNER}:${PRB}" | grep -c '"number"' || true)"
if [ "${existing:-0}" -gt 0 ]; then
  echo "PR for ${PRB} already open."; exit 0
fi
body='{"title":"Sync conflict: GitLab changes need resolution","head":"'"${PRB}"'","base":"'"${BRANCH}"'","body":"Automated sync could not fast-forward/merge GitLab `main` into GitHub `main` because both sides changed overlapping lines. Resolve here (merge this PR after fixing conflicts); the merged result syncs back to GitLab automatically.\n\nGitLab: https://'"${GL_HOST}"'/'"${GL_PATH}"'"}'
curl -fsS -X POST -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" "${api}/pulls" -d "$body" \
  | grep -oE '"html_url": *"[^"]*pull/[0-9]+"' | head -1 || true
echo "conflict PR opened on GitHub."
exit 0
