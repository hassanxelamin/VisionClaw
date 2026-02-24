#!/usr/bin/env bash
set -euo pipefail

# Opens a local tunnel from this Mac to the AWS-hosted OpenClaw gateway
# running on loopback inside the EC2 instance.

INSTANCE_NAME="${INSTANCE_NAME:-openclaw-gateway-prod-1}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}"
REMOTE_HOST="${REMOTE_HOST:-127.0.0.1}"
REMOTE_PORT="${REMOTE_PORT:-18789}"
LOCAL_PORT="${LOCAL_PORT:-28789}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] missing required command: $1" >&2
    exit 1
  }
}

need aws
need session-manager-plugin

echo "[info] region=${REGION} instance_name=${INSTANCE_NAME}"

INSTANCE_ID="$(aws ec2 describe-instances \
  --region "${REGION}" \
  --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)"

if [[ -z "${INSTANCE_ID}" || "${INSTANCE_ID}" == "None" ]]; then
  echo "[error] running instance not found for ${INSTANCE_NAME}" >&2
  exit 1
fi

echo "[info] instance_id=${INSTANCE_ID}"
echo "[info] local tunnel: 127.0.0.1:${LOCAL_PORT} -> ${REMOTE_HOST}:${REMOTE_PORT}"
echo "[info] press Ctrl+C to stop the tunnel"

aws ssm start-session \
  --region "${REGION}" \
  --target "${INSTANCE_ID}" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${REMOTE_HOST}\"],\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
