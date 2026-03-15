#!/usr/bin/env bash
set -e

# ── Nix store paths ──────────────────────────────────────────────────────────
GLIBC_DEV=/nix/store/41pf3md9zgpda9kwh6rzn5kaddf7i0lp-glibc-2.40-66-dev
GLIBC_LIB=/nix/store/g8zyryr9cr6540xsyg4avqkwgxpnwj2a-glibc-2.40-66/lib
GCC_LIB=/nix/store/8adzgnxs3s0pbj22qhk9zjxi1fqmz3xv-gcc-14.3.0/lib/gcc/x86_64-unknown-linux-gnu/14.3.0
SWIFTLIB=/nix/store/rqbxags7dc6qh446sdrv90b33jk376j0-swift-5.8-lib/lib/swift/linux
DISPATCH_LIB=/nix/store/1hw6f3aqcry1l51wg2x4nyip1ik55wn9-swift-corelibs-libdispatch-5.8/lib
DISPATCH_DEV=/nix/store/ab4krqvcs84d8447qq91v21wldkc0l0a-swift-corelibs-libdispatch-5.8-dev
SWIFT=/nix/store/vfh0ykchqadjb9kdnlmppp0rc3r1b2a9-swift-5.8/bin/swiftc
AUTOLINK=/nix/store/vfh0ykchqadjb9kdnlmppp0rc3r1b2a9-swift-5.8/bin/swift-autolink-extract
LD=/nix/store/ap35np2bkwaba3rxs3qlxpma57n2awyb-binutils-2.44/bin/ld.gold

SYSROOT=/tmp/smartpocket-sysroot
BUILD_DIR=/tmp/smartpocket-build
SRC_DIR="$(cd "$(dirname "$0")/Sources" && pwd)"
OUT="$(cd "$(dirname "$0")" && pwd)/smartpocketd"

echo "[build] SmartPocket Swift backend"

# ── Prepare sysroot (fake root so swiftc finds C headers) ───────────────────
mkdir -p "$SYSROOT/usr"
ln -sfn "$GLIBC_DEV/include" "$SYSROOT/usr/include" 2>/dev/null || true

# ── Build directory ──────────────────────────────────────────────────────────
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR/module-cache"

# ── Collect Swift source files ───────────────────────────────────────────────
SOURCES=()
for f in "$SRC_DIR"/*.swift; do
    SOURCES+=("$f")
done
echo "[build] Sources: ${#SOURCES[@]} files"

# ── Step 1: Compile all files together as one Swift module ──────────────────
# swiftc with -c and multiple files outputs one .o per file in the current dir
echo "[compile] All sources (one module pass)"
pushd "$BUILD_DIR" > /dev/null
"$SWIFT" \
    -sdk "$SYSROOT" \
    -I "$DISPATCH_DEV/include" \
    -module-cache-path "$BUILD_DIR/module-cache" \
    -module-name SmartPocket \
    -Onone \
    -c "${SOURCES[@]}"
popd > /dev/null

# ── Step 2: Collect generated .o files ──────────────────────────────────────
OBJ_FILES=()
for f in "$BUILD_DIR"/*.o; do
    OBJ_FILES+=("$f")
done
echo "[build] Object files: ${#OBJ_FILES[@]}"

# ── Step 3: Extract autolink flags ──────────────────────────────────────────
AUTOLINK_FILE="$BUILD_DIR/autolink.txt"
"$AUTOLINK" "${OBJ_FILES[@]}" -o "$AUTOLINK_FILE" 2>/dev/null || touch "$AUTOLINK_FILE"

# ── Step 4: Link ─────────────────────────────────────────────────────────────
echo "[link] Linking smartpocketd"
AUTOLINK_FLAGS=()
if [ -s "$AUTOLINK_FILE" ]; then
    while IFS= read -r flag; do
        [[ "$flag" =~ ^-l ]] && AUTOLINK_FLAGS+=("$flag")
    done < "$AUTOLINK_FILE"
fi

"$LD" \
    -pie --eh-frame-hdr -m elf_x86_64 \
    "$GLIBC_LIB/Scrt1.o" \
    "$GLIBC_LIB/crti.o" \
    "$GCC_LIB/crtbeginS.o" \
    -L"$SWIFTLIB" \
    -L"$GLIBC_LIB" \
    -L"$GCC_LIB" \
    -L"$DISPATCH_LIB" \
    -rpath "$SWIFTLIB" \
    -rpath "$DISPATCH_LIB" \
    -rpath "$GLIBC_LIB" \
    --dynamic-linker="$GLIBC_LIB/ld-linux-x86-64.so.2" \
    "$SWIFTLIB/x86_64/swiftrt.o" \
    "${OBJ_FILES[@]}" \
    "${AUTOLINK_FLAGS[@]}" \
    -lswift_StringProcessing \
    -lswift_Concurrency \
    -lswiftCore \
    -lswiftSwiftOnoneSupport \
    -lswiftGlibc \
    -ldispatch \
    -lc \
    "$GCC_LIB/crtendS.o" \
    "$GLIBC_LIB/crtn.o" \
    -o "$OUT"

echo "[build] Done → $OUT"
