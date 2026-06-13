#!/bin/bash
# Launch Blackjack Deluxe in DOSBox-X via QBASIC 1.1.
set -euo pipefail

DOSBOX="/Applications/dosbox-x.app/Contents/MacOS/DosBox"
QBASIC_DIR="/Users/jay/projects/MSDOS-QBASIC"
GAME_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -x "$DOSBOX" ]]; then
    echo "error: DOSBox-X not found at $DOSBOX" >&2
    exit 1
fi
if [[ ! -f "$QBASIC_DIR/Qbasic.exe" ]]; then
    echo "error: Qbasic.exe not found in $QBASIC_DIR" >&2
    exit 1
fi
if [[ ! -f "$GAME_DIR/BLACKJCK.BAS" ]]; then
    echo "error: BLACKJCK.BAS not found in $GAME_DIR" >&2
    exit 1
fi

# -working-dir auto-mounts C: to the game directory, so QBASIC goes on E:
exec "$DOSBOX" \
    -fastlaunch \
    -working-dir "$GAME_DIR" \
    -c "mount e $QBASIC_DIR" \
    -c "c:" \
    -c "e:\\qbasic.exe /RUN c:\\blackjck.bas"
