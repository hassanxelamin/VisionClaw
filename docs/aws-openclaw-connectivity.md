# AWS OpenClaw Connectivity (iPhone Prototype)

## Purpose
Document the validated network shape for the current AWS-hosted OpenClaw deployment and how to smoke-test it safely for VisionClaw iPhone bring-up.

## Current Topology (2026-02-24)
- EC2 instance name: `openclaw-gateway-prod-1`
- Instance ID: `i-08624bba5c1399227`
- OpenClaw gateway process listens on loopback:
  - `127.0.0.1:18789`
  - `127.0.0.1:18792`
- Security group `sg-0802be85a2f367cf7` has no inbound rules.
- Direct public access to `44.248.174.130:18789` times out (expected in this configuration).
- Tailscale installed, but no `serve`/`funnel` config currently active.

## Implications for iPhone VisionClaw
- The current EC2 gateway is not directly reachable from iPhone over public Internet.
- Milestone 1 should assume one of these paths before relying on remote gateway:
  1. LAN-hosted OpenClaw (`bind: "lan"`) on a Mac reachable by iPhone.
  2. Tailscale-based path with explicit service exposure.
  3. Reverse proxy/TLS front door with controlled auth (later hardening phase).

## Smoke Test Workflow
Use `scripts/openclaw_smoke.sh` from a trusted machine with AWS CLI + SSM access.

```bash
./scripts/openclaw_smoke.sh
```

Checks performed:
- AWS identity and target instance visibility.
- EC2 security-group inbound rule summary.
- OpenClaw listener sockets on the instance via SSM.
- Tailscale serve/funnel status on the instance via SSM.
- Optional best-effort direct curl probe to public IP:18789.

## Security Notes
- Do not store gateway tokens in docs, scripts, or Obsidian logs.
- Keep token auth enabled on gateway.
- Keep notes focused on topology and state only.
