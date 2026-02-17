# Uri Claude Usage App v1 — Handover

## What It Is
A macOS menu bar widget that shows your Claude Pro subscription usage at a glance — no need to open claude.ai to check how much you've used.

## The Problem
Claude Pro has rolling usage limits (5-hour session window + weekly cap). The only way to check your remaining usage is to navigate to claude.ai/settings/usage in a browser. For heavy users who rely on Claude for daily work, this friction leads to unexpected rate limits mid-task.

## The Solution
A persistent, always-visible indicator in the macOS menu bar — right next to Wi-Fi and battery. One glance tells you where you stand. One click shows the full breakdown with reset countdowns.

## How It Works
- Reads the same data as claude.ai/settings/usage via Anthropic's OAuth API
- Authenticates automatically using the Claude Code login already on your Mac
- Updates every 60 seconds
- Zero configuration needed — install and forget

## Value
- **Saves time** — no context-switching to check usage
- **Prevents surprises** — see limits approaching before they hit
- **Helps pace work** — plan heavy Claude tasks around reset windows

## Status
v1 — functional, stable, covers core use case. Built in one session.
