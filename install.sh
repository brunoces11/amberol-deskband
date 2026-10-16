#!/usr/bin/env bash
set -euo pipefail
DESKBAND_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "$DESKBAND_DIR/scripts/manage.py" install "$@"
