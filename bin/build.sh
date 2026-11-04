#!/usr/bin/env bash
# Build wrapper: reconcile the month-archive stubs, then run Hugo.
#
# Usage:
#   bin/build.sh            # build into ./public/
#   bin/build.sh server     # run the dev server (hugo server)
#   bin/build.sh <any hugo args>
#
# The generator must run before Hugo so the per-month archive pages exist
# when the site renders and its permalinks (/YYYY/MM/) resolve.
set -euo pipefail
cd "$(dirname "$0")/.."   # hugo/

# Stdlib only in the generator, so no bundler here — keep this bundler-free to
# match CI, where asciidoctor is a plain gem install. Hugo spawns the asciidoctor
# binary, and a bundler-only binstub fails in the spawned child.
ruby bin/generate_month_archives.rb

# Default to --minify for production parity with CI.
# Pass explicit args to override: ./bin/build.sh --gc
if [ $# -eq 0 ]; then
  mise exec -- hugo --minify
else
  mise exec -- hugo "$@"
fi
