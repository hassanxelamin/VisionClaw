# Milestone 2 Runbook (Jarvis Branding + Hardening Backlog)

## Purpose
Define post-M1.5 steps without destabilizing the working iPhone prototype.

## Current Baseline
- iPhone-first VisionClaw prototype with glasses flow.
- OpenClaw tool mode with fallback behavior planned in M1.5.
- Upstream-trackable structure preserved (`Gemini/`, `OpenClaw/`, `ViewModels/`, `Views/`).

## Phase 1: Branding Pass (Low Risk)
1. Rename app display name and bundle identifiers.
2. Update app icon and visual copy text.
3. Keep module/file layout intact.
4. Re-run smoke matrix after branding only.

## Phase 2: Configuration UX Cleanup (Medium Risk)
1. Improve settings copy for local vs remote OpenClaw endpoints.
2. Add validation hints for host/port/token format.
3. Keep runtime behavior unchanged during this phase.

## Phase 3: Security Hardening Backlog (Deferred)
1. Move Gemini key handling off-device (proxy/token broker).
2. Migrate local secret persistence to Keychain-backed storage.
3. Add TLS/reverse-proxy policy for non-LAN OpenClaw usage.
4. Add endpoint allowlist and stricter auth posture.

## Rollback Guidance
If any phase introduces regression:
1. Revert only the latest merge commit for that phase.
2. Re-run QA matrix (`docs/qa-openclaw-matrix.md`) focusing on QA-001..QA-005.
3. Record decision and mitigation in decisions log before proceeding.

## Required Manual Validation Before Any Distribution
- Glasses registration and stream stability.
- 3 successful OpenClaw tasks in a single session.
- Voice-only fallback behavior when OpenClaw unavailable.
- Permission and network interruption resilience.
