# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SaveCloud is a game save file cloud storage backend — a REST/HTTP API server built with **Vapor 4** (Swift web framework) that lets clients upload and retrieve game saves keyed by game hash. It also serves a minimal web UI for user account management.

## Build & Run Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Run the server
swift run

# Run tests
swift test

# Run a single test
swift test --filter AppTests.AppTests/testName

# Docker
docker-compose build
docker-compose up app
```

## Key Setup Requirements

Before running, the `Public/` directory must contain RSA key pair files used for JWT signing:
- `Public/jwt.pem` — private key
- `Public/jwtPublic.pem` — public key

The HTML template base directory is hardcoded in `Sources/App/entrypoint.swift`:
```swift
IHtmlNodeContainerUtility.sharedInstance.defaultBaseDir = "/Users/isaacpaul/Projects/swift-projects/SaveCloud/SaveCloud/Sources/App"
```
This must be updated when running on a new machine or in Docker.

The SQLite database is stored in the system Documents directory, resolved at runtime via `NSSearchPathForDirectoriesInDomains`.

## Architecture

### Framework
Vapor 4 (Swift) targeting macOS 13+. Swift 6 strict concurrency is enabled via `swiftSettings` in `Package.swift`.

### Local Package Dependencies
- **HRW** (`/Users/isaacpaul/Projects/swift-projects/HRW`) — custom HTML generation library. Provides `HTMLNode`, `IHtmlNodeContainerUtility`, and a `BindingPlugin` SPM plugin that binds `.html` template files to Swift `class` counterparts at build time.
- **GenHTML5** — also a local dependency (declared in `Package.swift` but not yet used in the `App` target).

### Authentication (Two-Track)
1. **JWT** (`JWTClaimAuthenticator`) — for API routes. Tokens are RS256-signed, 90-minute expiry. Refresh via `/api/v1/refresh` using a refresh token stored in the session table.
2. **Session cookies** (`UserSessionAuthenticator`) — for the web UI routes (login form, user edit pages). Passwords are hashed with Argon2.

JWT keys are loaded from `Public/` at startup in `configure.swift`. The `jwtPrivateKey` / `jwtPublicKey` globals are `nonisolated(unsafe)`.

### Database Layer
Uses **SQLite** via **GRDB** (not the SQLite.swift package — note the `Connection` / `Table` / `Expression` types come from GRDB's SQLite compatibility layer imported as `SQLite`).

Database access pattern — two classes per entity:
- **`Tbl*` class** (e.g., `TblSave`, `TBLGameHash`) — static helpers: column expressions, `createQuery()`, `toItem(_:)`, `toRow(_:)`, and domain-specific query methods.
- **Model class** (e.g., `Save`, `GameHash`) — conforms to `SQLItem` protocol and `Content` (Vapor's Codable response type). Delegates all DB logic back to its `Tbl*` counterpart.

The `SQLItem` protocol (in `SqliteItem.swift`) adds generic CRUD helpers as `Connection` extensions: `fetchAll`, `insert`, `update`, `upsert`, `delete`, `first(uuid:)`, etc.

`Database.getConnection()` / `Database.initDB()` are wrappers around `DBShared` which holds the global `DatabasePool`. Tables are created in `Sqlite.swift:createAllTables`.

### Routing (`routes.swift`)
- **Public web routes**: `GET /`, `GET /register`, `POST /register`, `POST /login`
- **JWT-authenticated API** (grouped under `JWTClaimAuthenticator`): `/api/v1/user`, `/api/v1/user/:id`
- **Session-authenticated web routes**: `POST /login`, `POST /user/edit`, `POST /user/change_password`, `GET /user/edit`
- Additional API routes for saves, game metadata, and game hashes are defined in their respective files under `Sources/App/Web/API/v1/` but must be registered in `routes.swift`.

### Web UI / HTML Generation
Pages follow a **VC (View Controller) pattern** — each page has:
- An `.html` template file (e.g., `HomePage.html`)
- A generated base Swift class (produced by the `BindingPlugin` from HRW)
- A `VC*` Swift subclass (e.g., `VCHomePage`) that adds dynamic data by manipulating the node tree

`HTMLNode` is made `ResponseEncodable` via `Extensions/Plot+Ext.swift`, so route handlers can return `HTMLNode` directly.

### Web File Organization
- Prefer folder structure that mirrors web URL structure as closely as practical.
- Keep Swift route/controller files and their `.html` templates in same route-family folder.
- Put shared helpers in `Shared/` only when reused by multiple route trees.
- Prefer canonical route ownership over older feature buckets. Example: `/profile/:id/games` code belongs under `Web/Profile/Games/`, not a generic `Web/User/` bucket.

### Validation
Request bodies that need validation conform to `IValidate` (in `Utility/IValidate.swift`), implementing `iterateErrors(_:)`. Call `.checkValdiation()` to throw a `400 Bad Request` with all errors joined.

### Pagination
API list endpoints accept `page`, `per_page`, `sort_by`, and `asc` query parameters. Parsed via `Request.getPageInfo()` into a `PageInfo<SortField>` struct. Sort field types (`SaveSortField`, `GameMetaSortField`) conform to `LosslessStringConvertible & DefaultConstructible`.

## Contributions

Contributors must sign commits with `git commit --signoff` to agree to the CLA in `CLA.txt`.

## Claude Workflow Rules

- **Commit after every change.** Make a git commit immediately before reporting a task as done.
- **Push after every commit.** After every commit, push the branch to the remote immediately.
- **Never modify branches that do not begin with `claude`.** If the current branch does not start with `claude`, stop and ask the user before making any changes.
- **Commit footer format.** End every commit message with `Automated-By: <model name>` (no email address). Do not use `Co-Authored-By`.

## Behavior Preservation Rules

- Treat existing code as intentional design unless there is strong repo evidence otherwise. Prefer extending or reshaping current APIs, models, and flows over deleting and rebuilding them.
- Full-file replacement is allowed when the existing code is fully restored, including behavior, structure, comments, and intentional formatting, with new behavior added on top. Do not use file replacement to silently drop existing behavior, comments, formatting choices, or simplify away intentional structure.
- Preserve existing user-visible behavior unless the user explicitly asked to change it.
- Do not prioritize backward-compatibility shims, aliases, or transitional code when they increase complexity. This app is not released yet, so prefer the simpler final design.
- Do not remove or rewrite useful comments without a concrete reason.
- If a failing test is caused by environment, template lookup, or tooling behavior, do not hide it by changing app behavior.
- When in doubt, ask before changing a route contract, response contract, or page flow.
