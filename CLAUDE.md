# Yury Claude Usage App — Project Guide

## What This Is
A native macOS menu bar widget that displays real-time Claude Pro subscription usage (current session % and weekly %). Built with Swift/SwiftUI using `MenuBarExtra`. No dock icon — lives entirely in the menu bar.

## Architecture

```
ClaudeUsage/
├── ClaudeUsageApp.swift      — App entry point. MenuBarExtra with .window style.
├── UsageService.swift        — Fetches usage from Anthropic OAuth API every 60s.
│                               Published @ObservableObject driving the UI.
├── KeychainHelper.swift      — Reads OAuth token from macOS Keychain via `security` CLI.
│                               Caches token for 5 min to avoid repeated reads.
├── MenuBarRenderer.swift     — Renders the retro-digital NSImage for the menu bar:
│                               Claude logo PNG + orange segmented bar + percentage.
├── DetailPopover.swift       — Dropdown panel matching claude.ai/settings/usage style.
│                               Shows session %, weekly %, reset countdowns.
└── Resources/
    └── claude-logo.png       — Official Claude starburst logo (transparent PNG).
```

## Data Flow
1. `KeychainHelper` reads OAuth token from `Claude Code-credentials` keychain entry
   - Supports two JSON formats: nested `{"claudeAiOauth": {"accessToken": ...}}` (legacy) and flat `{"accessToken": ...}` (current)
2. `UsageService` calls `GET https://api.anthropic.com/api/oauth/usage` with Bearer token and `User-Agent: claude-code/X.X.X` header (required by Cloudflare)
3. API returns `{ five_hour: { utilization: 55.0, resets_at: "..." }, seven_day: { ... } }`
4. `MenuBarRenderer` generates an NSImage from the session percentage
5. `DetailPopover` shows full breakdown when user clicks the widget

## Key Technical Decisions
- **`security` CLI over Security framework** — avoids macOS Keychain GUI password prompts on every poll
- **Token caching (5 min)** — reduces Keychain reads from 1/min to 1/5min
- **SPM over Xcode project** — simpler, no .xcodeproj files, builds with `swift build`
- **NSImage rendering** — MenuBarExtra label only accepts Image+Text, so the entire widget (logo + bar + %) is rendered as a single NSImage
- **LSUIElement = true** — no dock icon, menu bar only
- **User-Agent header** — Anthropic's API requires `User-Agent: claude-code/X.X.X` or Cloudflare blocks with 429
- **429 backoff** — exponential backoff (60s→120s→240s→300s max) on rate limit, resets to 60s on success

## Build & Run
```bash
./build-and-run.sh    # Build and launch (debug)
./install.sh          # Build, install to /Applications, launch
claude-usage          # Start (if installed)
claude-usage quit     # Stop
claude-usage rebuild  # Rebuild from source and reinstall
```

## Dependencies
- macOS 13+ (Ventura) — required for `MenuBarExtra`
- Swift 5.9+
- Claude Code must be logged in (OAuth token in Keychain)
- No third-party packages
