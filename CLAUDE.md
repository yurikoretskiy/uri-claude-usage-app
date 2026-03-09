# Yury Claude Usage App — Project Guide

## What This Is
A native macOS menu bar widget that displays real-time Claude Pro/Max subscription usage. Shows current session %, weekly %, and per-model limits (e.g. Sonnet, Opus). Built with Swift/SwiftUI using `MenuBarExtra`. No dock icon — lives entirely in the menu bar.

## Architecture

```
ClaudeUsage/
├── ClaudeUsageApp.swift      — App entry point. MenuBarExtra with .window style.
├── UsageService.swift        — Fetches usage from Anthropic OAuth API every 60s.
│                               Parses five_hour, seven_day, and dynamic model-specific
│                               limits (seven_day_sonnet, seven_day_opus, etc.).
│                               Published @ObservableObject driving the UI.
├── KeychainHelper.swift      — Reads OAuth token. Primary: ~/.claude/.credentials.json.
│                               Fallback: macOS Keychain via `security` CLI.
│                               Caches token for 5 min to avoid repeated reads.
├── MenuBarRenderer.swift     — Renders the retro-digital NSImage for the menu bar:
│                               Claude logo PNG + orange segmented bar + percentage.
├── DetailPopover.swift       — Dropdown panel matching claude.ai/settings/usage style.
│                               Shows session %, weekly %, per-model limits with progress bars.
└── Resources/
    └── claude-logo.png       — Official Claude starburst logo (transparent PNG).
```

## Data Flow
1. `KeychainHelper` reads OAuth token from `~/.claude/.credentials.json` (primary) or `Claude Code-credentials` keychain entry (fallback)
   - Supports two JSON formats: nested `{"claudeAiOauth": {"accessToken": ...}}` (legacy) and flat `{"accessToken": ...}` (current)
2. `UsageService` calls `GET https://api.anthropic.com/api/oauth/usage` with Bearer token, `anthropic-beta: oauth-2025-04-20`, and `User-Agent: claude-code/X.X.X` header (required by Cloudflare)
3. API returns active fields (`five_hour`, `seven_day`, `seven_day_sonnet`, etc.) plus null/inactive fields — parser dynamically discovers any `seven_day_*` model-specific limits
4. `MenuBarRenderer` generates an NSImage from the session percentage
5. `DetailPopover` shows full breakdown: session, weekly "All models", and per-model rows (Sonnet, Opus, etc.)

## API Response Shape (as of March 2026)
```json
{
  "five_hour": { "utilization": 13.0, "resets_at": "..." },
  "seven_day": { "utilization": 38.0, "resets_at": "..." },
  "seven_day_sonnet": { "utilization": 2.0, "resets_at": "..." },
  "seven_day_opus": null,
  "seven_day_oauth_apps": null,
  "seven_day_cowork": null,
  "iguana_necktie": null,
  "extra_usage": { "is_enabled": false, ... }
}
```
Only non-null `seven_day_*` entries with a `utilization` field are shown. Unknown/null fields are silently skipped.

## Key Technical Decisions
- **Credentials file first, Keychain fallback** — reading `~/.claude/.credentials.json` directly avoids macOS Keychain GUI permission popups. Keychain (`security` CLI) is only used if the file is missing/unreadable.
- **Token caching (5 min)** — reduces credential reads from 1/min to 1/5min
- **SPM over Xcode project** — simpler, no .xcodeproj files, builds with `swift build`
- **NSImage rendering** — MenuBarExtra label only accepts Image+Text, so the entire widget (logo + bar + %) is rendered as a single NSImage
- **LSUIElement = true** — no dock icon, menu bar only
- **User-Agent header** — Anthropic's API requires `User-Agent: claude-code/X.X.X` or Cloudflare blocks with 429
- **429 retry + backoff** — retries once with Retry-After header + jitter, then backs off (60s→120s max), resets to 60s on success. Shows cached data silently during backoff.
- **Network error retry** — retries once after 3s on transient errors (TLS, DNS, timeout) before backing off
- **Dynamic model parsing** — automatically discovers new `seven_day_*` model limits without code changes

## Build & Run
```bash
./build-and-run.sh    # Build and launch (debug)
claude-usage          # Start (if installed in /Applications)
claude-usage quit     # Stop
claude-usage rebuild  # Rebuild from source and reinstall
```

## Dependencies
- macOS 13+ (Ventura) — required for `MenuBarExtra`
- Swift 5.9+
- Claude Code must be logged in (`~/.claude/.credentials.json` must exist with valid OAuth token)
- No third-party packages

## Breakage History & Lessons (Feb–Mar 2026)

| Date | Issue | Root Cause | Fix |
|------|-------|-----------|-----|
| Feb 24 | Keychain reading broke | macOS switched to hex-encoded credentials | Added hex decoding in KeychainHelper |
| Mar 4 | OAuth 401 recurring | No token auto-refresh | Added token refresh flow |
| Mar 6 | Cloudflare 429 | Anthropic added bot protection | Added `User-Agent: claude-code/X.X.X` header |
| Mar 8 | Missing refreshToken crash | Keychain sync only stored accessToken | Store full creds (accessToken + refreshToken + expiresAt) |
| Mar 8 | Only 2 of 3 limits shown | API added model-specific limits | Dynamic `seven_day_*` parsing |

**Key lesson**: Read credentials from the file (`~/.claude/.credentials.json`) as the primary source, not the Keychain. The Keychain is a fallback only. Never iterate/probe Keychain entries — it triggers macOS permission popups.
