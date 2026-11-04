#!/usr/bin/env bash
# deploy-server.sh — make the served tree match the latest successful build.
#
# Runs on the *server*, not on the machine you edit on. It needs no Ruby, no
# Hugo, no rsync: it only moves finished files into place.
#
# HOW THIS WORKS
#
# GitHub Actions builds the site on every push to `main` and force-pushes a
# single root commit to the orphan branch `build`. That branch contains the
# full source tree *and* the generated site in ./public.
#
# The server holds one clone of `build`:
#
#   ~/robot_librarian_source/          <- this checkout (branch: build)
#   ~/robot_librarian_source/public/   <- the served tree, .htaccess included
#   ~/robotlibrarian.billdueber.com    <- symlink -> ~/robot_librarian_source/public
#
# This script moves that checkout forward in place. Apache serves ./public
# directly; nothing is copied anywhere.
#
# NOTE: `public/` is tracked on `build`, which is what makes `git reset --hard`
# sufficient — tracked files that no longer exist upstream are deleted for you.
# That is the whole reason the branch carries the generated output.
#
# WHY NOT `git pull`
#
# History is force-pushed, so it is never fast-forward. `git pull` would fail
# with "not possible to fast-forward". We reset to FETCH_HEAD instead of a local
# `build` ref for the same reason: updating a shallow ref across repeated
# force-pushes trips "shallow update not allowed".
#
# FIRST-TIME INSTALL (once, by hand)
#
#   git clone --depth 1 --branch build \
#     https://github.com/billdueber/rl2026.git ~/robot_librarian_source
#   ln -s ~/robot_librarian_source/public ~/robotlibrarian.billdueber.com
#
# Gotcha: no trailing slash on the symlink target, and the link name must not
# already exist. If the DreamHost panel already created that directory,
# `ln -s .../public ~/robotlibrarian.billdueber.com/` silently creates the link
# *inside* it and serves nothing. Remove the panel directory first.
#
# CRON (DreamHost panel -> Goodies -> Cron Jobs, or a crontab entry)
#
#   0 */2 * * * $HOME/robot_librarian_source/bin/deploy-server.sh >> $HOME/deploy.log 2>&1
#
# ENVIRONMENT
#
#   BRANCH   branch to deploy        (default: build)
#   REMOTE   git remote name or URL  (default: origin)
#   WEBROOT  optional served path, checked after the update for sanity
#
set -euo pipefail

BRANCH="${BRANCH:-build}"
REMOTE="${REMOTE:-origin}"
WEBROOT="${WEBROOT:-}"

# Resolve the checkout from this script's own location — it lives in the
# checkout, so no path needs configuring.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if ! ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "error: $SCRIPT_DIR is not inside a git checkout" >&2
  exit 1
fi

# Single-flight: a slow fetch must not overlap the next cron tick.
#
# Kept inside .git rather than $TMPDIR: cron and interactive shells routinely
# disagree about TMPDIR, and two different lock paths means no lock at all.
# .git is per-checkout, always writable, and never served.
LOCK="$ROOT/.git/rl2026-deploy.lock"
if [ -d "$LOCK" ]; then
  # Recover from a run that was killed before its trap fired.
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then
    echo "removing stale lock: $LOCK" >&2
    rmdir "$LOCK" 2>/dev/null || true
  fi
fi

if ! mkdir "$LOCK" 2>/dev/null; then
  echo "another deploy is in progress (lock: $LOCK); skipping" >&2
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

BEFORE="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo none)"

git -C "$ROOT" fetch --depth 1 --no-tags --force "$REMOTE" "$BRANCH"

# Validate the incoming build BEFORE touching the served tree. A build that
# produced no index.html is not one we want to serve, and reset --hard would
# have already destroyed the working one by the time a post-check ran.
if ! git -C "$ROOT" cat-file -e "FETCH_HEAD:public/index.html" 2>/dev/null; then
  echo "error: fetched $BRANCH has no public/index.html; leaving the site untouched" >&2
  exit 1
fi

git -C "$ROOT" reset --hard FETCH_HEAD --quiet
# Drop anything untracked left behind (e.g. from an older branch layout).
# Ignored files are kept, so a stray editor swap file is harmless either way.
git -C "$ROOT" clean -fdq

AFTER="$(git -C "$ROOT" rev-parse HEAD)"

if [ "$BEFORE" = "$AFTER" ]; then
  echo "up to date at ${AFTER:0:7}"
else
  echo "deployed ${BEFORE:0:7} -> ${AFTER:0:7}"
fi

# Optional: catch a broken or missing symlink early.
if [ -n "$WEBROOT" ] && [ ! -f "$WEBROOT/index.html" ]; then
  echo "warning: $WEBROOT/index.html is missing — check the webroot symlink" >&2
fi
