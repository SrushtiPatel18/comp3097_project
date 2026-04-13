// SmartPocket backend — start script (pure Swift, no imports)
// Build then launch.  Run from the backend/ directory:
//   swift run.swift
//   swift run.swift --port=8080 --data-dir=./data

// ── C interop via @_silgen_name ───────────────────────────────────────────────
@_silgen_name("system") @discardableResult
func c_system(_ cmd: UnsafePointer<Int8>?) -> Int32

@_silgen_name("access") @discardableResult
func c_access(_ path: UnsafePointer<Int8>?, _ mode: Int32) -> Int32

@_silgen_name("exit") func c_exit(_ code: Int32) -> Never

// ── Helpers ───────────────────────────────────────────────────────────────────

@discardableResult
func sh(_ cmd: String) -> Int32 { cmd.withCString { c_system($0) } }

func exists(_ path: String) -> Bool { path.withCString { c_access($0, 0) == 0 } }

// ── Runtime library paths ─────────────────────────────────────────────────────
let DISPATCH = "/nix/store/1hw6f3aqcry1l51wg2x4nyip1ik55wn9-swift-corelibs-libdispatch-5.8/lib"
let SWIFTLIB = "/nix/store/rqbxags7dc6qh446sdrv90b33jk376j0-swift-5.8-lib/lib/swift/linux"
let GLIBCLIB = "/nix/store/g8zyryr9cr6540xsyg4avqkwgxpnwj2a-glibc-2.40-66/lib"
let LD_PATH  = "\(DISPATCH):\(SWIFTLIB):\(GLIBCLIB)"

// ── CLI argument parsing ──────────────────────────────────────────────────────
func argValue(prefix: String) -> String? {
    for arg in CommandLine.arguments {
        if arg.hasPrefix(prefix) {
            return String(arg[arg.index(arg.startIndex, offsetBy: prefix.count)...])
        }
    }
    return nil
}

let PORT     = argValue(prefix: "--port=")     ?? "8080"
let DATA_DIR = argValue(prefix: "--data-dir=") ?? "./data"
let BINARY   = "./smartpocketd"

// ── Build if binary is absent ─────────────────────────────────────────────────
if !exists(BINARY) {
    print("[run] Binary not found — building first...")
    let code = sh("swift build.swift")
    if code != 0 { c_exit(code) }
}

// ── Ensure data directory exists ──────────────────────────────────────────────
sh("mkdir -p '\(DATA_DIR)'")

// ── Launch with the required shared libraries on LD_LIBRARY_PATH ──────────────
print("[run] Starting SmartPocket backend on port \(PORT)")
let exitCode = sh("LD_LIBRARY_PATH='\(LD_PATH)' \(BINARY) --port \(PORT) --data-dir '\(DATA_DIR)'")
c_exit(exitCode)
