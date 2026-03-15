#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/smartpocketd"

if [ ! -f "$BINARY" ]; then
    echo "[run] Binary not found. Building first..."
    cd "$SCRIPT_DIR" && bash build.sh
fi

DISPATCH_LIB=/nix/store/1hw6f3aqcry1l51wg2x4nyip1ik55wn9-swift-corelibs-libdispatch-5.8/lib
SWIFTLIB=/nix/store/rqbxags7dc6qh446sdrv90b33jk376j0-swift-5.8-lib/lib/swift/linux
GLIBC_LIB=/nix/store/g8zyryr9cr6540xsyg4avqkwgxpnwj2a-glibc-2.40-66/lib

DATA_DIR="${DATA_DIR:-$SCRIPT_DIR/data}"
PORT="${PORT:-8080}"

mkdir -p "$DATA_DIR"

exec env \
    LD_LIBRARY_PATH="$DISPATCH_LIB:$SWIFTLIB:$GLIBC_LIB:$LD_LIBRARY_PATH" \
    "$BINARY" --port "$PORT" --data-dir "$DATA_DIR"
