#!/usr/bin/env bash
# Compact sessions listed in a private, locally configured manifest.
set -eu
cd "$(dirname "$0")/.." || exit 1
py -V:3.12 -I scripts/compact_sessions.py "$@"
