#!/usr/bin/env bash
set -euo pipefail

if command -v fvm >/dev/null 2>&1; then
  fvm flutter gen-l10n
else
  flutter gen-l10n
fi
