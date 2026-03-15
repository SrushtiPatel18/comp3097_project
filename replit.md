# SmartPocket

A personal finance tracker originally written as a native iOS app (SwiftUI + SwiftData). The original iOS source is preserved in `SmartPocketIOS/`. A fully functional web frontend (React + Vite) connects to a custom Swift HTTP backend.

## Project Structure

```
SmartPocketIOS/         Original iOS/Swift source code (SwiftUI + SwiftData)

web/                    React + Vite web frontend (port 5000)
  ├── src/
  │   ├── App.jsx                   Root: tab nav + loading/error states
  │   ├── HomeView.jsx              Budget dashboard with recent transactions
  │   ├── TransactionsView.jsx      Full list with search, filter, CRUD
  │   ├── ReportsView.jsx           Pie chart (recharts) + calendar date picker
  │   ├── SettingsView.jsx          Budget edit, category CRUD, data reset
  │   ├── AddTransactionModal.jsx   Add/edit bottom sheet form
  │   ├── TransactionDetailModal.jsx View/edit/delete detail sheet
  │   ├── store.js                  API client + state (calls Swift backend)
  │   └── utils.js                  CAD formatting, category icons, chart colors
  └── vite.config.js    Port 5000; proxies /api → http://localhost:8080

backend/                Pure-Swift HTTP backend (port 8080)
  ├── Sources/
  │   ├── main.swift        Entry point, CLI flag parsing, server boot
  │   ├── HTTP.swift        POSIX socket server, HTTP parser, response builder
  │   ├── Router.swift      URL pattern router with path parameters
  │   ├── Handlers.swift    REST handlers for transactions/categories/settings
  │   ├── Models.swift      Transaction, Category, Settings structs + validation
  │   ├── Storage.swift     File-based JSON persistence to ./data/
  │   └── JSON.swift        Full JSON encoder + recursive-descent parser
  ├── build.swift       Pure-Swift build script: swiftc -c + ld.gold link
  ├── run.swift         Pure-Swift launcher: builds if needed, sets LD_LIBRARY_PATH
  └── data/             Persisted JSON files (transactions, categories, settings)
```

## Backend API

All routes return `application/json`. CORS headers are set on every response.

| Method | Path                    | Description                         |
|--------|-------------------------|-------------------------------------|
| GET    | /health                 | Server status                       |
| GET    | /transactions           | List all (optional ?categoryId=...)  |
| POST   | /transactions           | Create transaction                  |
| GET    | /transactions/:id       | Get one                             |
| PUT    | /transactions/:id       | Update (partial patch)              |
| DELETE | /transactions/:id       | Delete → 204                        |
| GET    | /categories             | List all categories                 |
| POST   | /categories             | Create category                     |
| GET    | /categories/:id         | Get one                             |
| PUT    | /categories/:id         | Update                              |
| DELETE | /categories/:id         | Delete (user-created only) → 204    |
| GET    | /settings               | Get settings                        |
| PUT    | /settings               | Update settings                     |

## Features

- Budget tracking with monthly progress bar (CAD)
- Add / edit / delete transactions (income & expenses)
- Category-based spending with pie chart
- Calendar view to browse transactions by date
- Full-text search and income/expense filtering
- Custom category management
- Persistent JSON file storage (backend/data/)

## Tech Stack

- **Frontend**: React 19, Vite 8, Recharts
- **Backend**: Swift 5.8 (pure Glibc — no Foundation, no Vapor, no SwiftPM)
- **Storage**: JSON files via POSIX file I/O
- **iOS** (original): Swift 5.8, SwiftUI, SwiftData, Charts

## Compilation Notes (Backend)

The Replit Swift 5.8 environment is a minimal toolchain — Foundation is unavailable. The backend is built entirely with:
- `import Glibc` for POSIX syscalls (sockets, file I/O, time)
- Manual two-step build: `swiftc -c` (all sources together) → `ld.gold` with explicit nix store paths
- A fake sysroot pointing glibc headers at the nix store path
- Runtime: `LD_LIBRARY_PATH` set to libdispatch + Swift stdlib + glibc lib paths

Key nix paths used in build.swift:
- `glibc-2.40-66-dev` — C system headers
- `swift-corelibs-libdispatch-5.8-dev` — dispatch headers
- `swift-5.8` — swiftc, swift-autolink-extract
- `swift-5.8-lib` — swiftrt.o, libswiftCore.so
- `binutils-2.44/bin/ld.gold` — linker

### Build quirk: LD_LIBRARY_PATH
The `swift` interpreter wrapper injects its own `LD_LIBRARY_PATH` which conflicts
with `swiftc`'s RPATH. The compile step therefore uses `env -u LD_LIBRARY_PATH`
so `swiftc` uses its own RPATH (glibc-2.37) for compilation. The binary itself
runs under glibc-2.40 via `LD_LIBRARY_PATH` set in `run.swift`.

## Running

- `Start application` workflow: `cd web && npm run dev` (port 5000, webview)
- `Swift Backend` workflow: `cd backend && swift run.swift` (port 8080, console)

To rebuild the backend binary: `cd backend && swift build.swift`

## Deployment

Static site config: build `cd web && npm run build`, public dir `web/dist`.
For production backend deployment, run `swift backend/build.swift` then `swift backend/run.swift`.
