# iPhone + AWS OpenClaw Quickstart (Works-Now Path)

This gives the iPhone app a reachable OpenClaw endpoint without changing AWS
security-group ingress.

## Why this path
- Your EC2 OpenClaw gateway is loopback-only (`127.0.0.1:18789`).
- Security group has no inbound rules.
- iPhone cannot directly reach that endpoint.

So we bridge it through your Mac:
1. Mac opens an AWS SSM tunnel to EC2 loopback.
2. Mac exposes that tunnel to your LAN for iPhone access.

## Prerequisites
- iPhone and Mac on the same Wi-Fi network.
- AWS CLI configured on Mac.
- AWS Session Manager plugin installed (`session-manager-plugin`).
- `socat` installed on Mac (`brew install socat`).

## Step 1: Start AWS tunnel (Terminal A)
```bash
cd /path/to/your/VisionClaw/scripts
./openclaw_start_ssm_tunnel.sh
```

Default tunnel:
- `127.0.0.1:28789` (Mac) -> `127.0.0.1:18789` (EC2)

Keep Terminal A running.

## Step 2: Expose tunnel to LAN (Terminal B)
```bash
cd /path/to/your/VisionClaw/scripts
./openclaw_start_lan_proxy.sh
```

Default LAN proxy:
- `0.0.0.0:18789` (Mac LAN) -> `127.0.0.1:28789` (Mac local tunnel)

Keep Terminal B running.

## Step 3: Configure iPhone app
In VisionClaw iOS app Settings:
- OpenClaw Host: `http://<YourMacLocalHostName>.local`
- OpenClaw Port: `18789`
- OpenClaw Gateway Token: your gateway token

Then:
1. Start streaming (glasses or iPhone mode)
2. Tap `AI` to start Gemini
3. Confirm OpenClaw status turns green

## Quick health checks
On Mac:
```bash
curl http://127.0.0.1:28789/health
curl http://127.0.0.1:18789/health
```

Both should return healthy responses while the bridge is running.

## Stop
- Ctrl+C in Terminal B (LAN proxy)
- Ctrl+C in Terminal A (SSM tunnel)

## Security note
- This only exposes OpenClaw on your local network while Terminal B is running.
- No AWS public ingress changes are required for this flow.
