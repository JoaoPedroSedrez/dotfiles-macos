#!/bin/sh
# Git filter for configs/claude/settings.json (wired in .gitattributes).
#
# Claude Code only reads `autoMode` from user settings, so the work-specific
# block has to live in ~/.claude/settings.json, which is this file. To keep it
# out of the public repo:
#   clean  (git add)      strips `autoMode`
#   smudge (git checkout) merges configs/claude/settings.px.local.json back in
# The .local.json is gitignored. Registered by install.conf.yaml; without it
# git just stores the file as-is.
set -e
local_json="configs/claude/settings.px.local.json"
case "$1" in
  clean) jq 'del(.autoMode)' ;;
  smudge)
    if [ -f "$local_json" ]; then jq -s '.[0] * .[1]' - "$local_json"; else cat; fi ;;
  *) echo "usage: $0 clean|smudge" >&2; exit 2 ;;
esac
