// SmartPocket backend — build script (pure Swift, no imports)
// Run from the backend/ directory:  swift build.swift

// ── C interop via @_silgen_name ───────────────────────────────────────────────
@_silgen_name("system") @discardableResult
func c_system(_ cmd: UnsafePointer<Int8>?) -> Int32

@_silgen_name("exit") func c_exit(_ code: Int32) -> Never

@_silgen_name("access") @discardableResult
func c_access(_ path: UnsafePointer<Int8>?, _ mode: Int32) -> Int32

@_silgen_name("getcwd")
func c_getcwd(_ buf: UnsafeMutablePointer<Int8>?, _ size: Int) -> UnsafeMutablePointer<Int8>?

// ── Helper ────────────────────────────────────────────────────────────────────
func sh(_ cmd: String, allowFailure: Bool = false) -> Int32 {
    let code = cmd.withCString { c_system($0) }
    if code != 0 && !allowFailure {
        print("[build] Command failed (exit \(code))")
        c_exit(1)
    }
    return code
}

// ── Nix store paths ───────────────────────────────────────────────────────────
let GLIBC_DEV    = "/nix/store/41pf3md9zgpda9kwh6rzn5kaddf7i0lp-glibc-2.40-66-dev"
let GLIBC_LIB    = "/nix/store/g8zyryr9cr6540xsyg4avqkwgxpnwj2a-glibc-2.40-66/lib"
let GCC_LIB      = "/nix/store/8adzgnxs3s0pbj22qhk9zjxi1fqmz3xv-gcc-14.3.0/lib/gcc/x86_64-unknown-linux-gnu/14.3.0"
let SWIFTLIB     = "/nix/store/rqbxags7dc6qh446sdrv90b33jk376j0-swift-5.8-lib/lib/swift/linux"
let DISPATCH_LIB = "/nix/store/1hw6f3aqcry1l51wg2x4nyip1ik55wn9-swift-corelibs-libdispatch-5.8/lib"
let DISPATCH_DEV = "/nix/store/ab4krqvcs84d8447qq91v21wldkc0l0a-swift-corelibs-libdispatch-5.8-dev"
let SWIFTC       = "/nix/store/vfh0ykchqadjb9kdnlmppp0rc3r1b2a9-swift-5.8/bin/swiftc"
let AUTOLINK     = "/nix/store/vfh0ykchqadjb9kdnlmppp0rc3r1b2a9-swift-5.8/bin/swift-autolink-extract"
let LD           = "/nix/store/ap35np2bkwaba3rxs3qlxpma57n2awyb-binutils-2.44/bin/ld.gold"

let SYSROOT   = "/tmp/smartpocket-sysroot"
let BUILD_DIR = "/tmp/smartpocket-build"
let OUT       = "./smartpocketd"

// Resolve current working directory so Sources path is absolute after cd BUILD_DIR
var cwdBuf = [Int8](repeating: 0, count: 4096)
let cwdPtr = c_getcwd(&cwdBuf, cwdBuf.count)
var BACKEND_DIR = "/home/runner/workspace/backend"  // fallback
if cwdPtr != nil {
    BACKEND_DIR = String(cString: cwdBuf)
}
let SRC_DIR = "\(BACKEND_DIR)/Sources"

print("[build] SmartPocket Swift backend")

// 1. Prepare sysroot
sh("mkdir -p \(SYSROOT)/usr && ln -sfn \(GLIBC_DEV)/include \(SYSROOT)/usr/include 2>/dev/null || true", allowFailure: true)

// 2. Clean build directory
sh("rm -rf \(BUILD_DIR) && mkdir -p \(BUILD_DIR)/module-cache")

// 3. Compile all Swift sources together as a single module
//    swiftc with -c writes one .o per file into the working directory
print("[compile] All sources → SmartPocket module")
// env -u LD_LIBRARY_PATH lets swiftc use its own RPATH (glibc-2.37) without
// conflicts from the swift wrapper's injected LD_LIBRARY_PATH.
sh("cd \(BUILD_DIR) && env -u LD_LIBRARY_PATH \(SWIFTC) -sdk \(SYSROOT) -I \(DISPATCH_DEV)/include -module-cache-path \(BUILD_DIR)/module-cache -module-name SmartPocket -Onone -c \(SRC_DIR)/*.swift 2>&1")

// 4. Extract autolink flags
let autolinkFile = "\(BUILD_DIR)/autolink.txt"
sh("\(AUTOLINK) \(BUILD_DIR)/*.o -o \(autolinkFile) 2>/dev/null || touch \(autolinkFile)", allowFailure: true)

// 5. Build the autolink flags argument (strip non -l lines in shell)
let alFlags = "$(grep -E '^-l' \(autolinkFile) 2>/dev/null | tr '\\n' ' ' || true)"

// 6. Link
print("[link] Linking smartpocketd")
sh(  "\(LD)"
   + " -pie --eh-frame-hdr -m elf_x86_64"
   + " \(GLIBC_LIB)/Scrt1.o \(GLIBC_LIB)/crti.o \(GCC_LIB)/crtbeginS.o"
   + " -L\(SWIFTLIB) -L\(GLIBC_LIB) -L\(GCC_LIB) -L\(DISPATCH_LIB)"
   + " -rpath \(SWIFTLIB) -rpath \(DISPATCH_LIB) -rpath \(GLIBC_LIB)"
   + " --dynamic-linker=\(GLIBC_LIB)/ld-linux-x86-64.so.2"
   + " \(SWIFTLIB)/x86_64/swiftrt.o"
   + " \(BUILD_DIR)/*.o"
   + " \(alFlags)"
   + " -lswift_StringProcessing -lswift_Concurrency -lswiftCore -lswiftSwiftOnoneSupport -lswiftGlibc -ldispatch -lc"
   + " \(GCC_LIB)/crtendS.o \(GLIBC_LIB)/crtn.o"
   + " -o \(OUT)"
)

print("[build] Done → \(OUT)")
