#!/usr/bin/env bash
set -euo pipefail

INSTANCE_NAME="openclaw-gateway-prod-1"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}"

echo "[info] region=${REGION} instance_name=${INSTANCE_NAME}"

aws sts get-caller-identity --output table

INSTANCE_ID=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

if [[ -z "${INSTANCE_ID}" || "${INSTANCE_ID}" == "None" ]]; then
  echo "[error] running instance not found for ${INSTANCE_NAME}" >&2
  exit 1
fi

echo "[info] instance_id=${INSTANCE_ID}"

SG_ID=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

echo "[info] security_group=${SG_ID}"
aws ec2 describe-security-groups --region "${REGION}" --group-ids "${SG_ID}" \
  --query 'SecurityGroups[].{GroupId:GroupId,Inbound:IpPermissions}' --output table

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "${REGION}" \
  --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "[info] public_ip=${PUBLIC_IP}"

COMMAND_ID=$(aws ssm send-command \
  --region "${REGION}" \
  --instance-ids "${INSTANCE_ID}" \
  --document-name 'AWS-RunShellScript' \
  --comment 'openclaw-smoke-check' \
  --parameters commands='["set -e","sudo ss -ltnp | egrep \"18789|18792\" || true","sudo tailscale serve status || true","sudo tailscale funnel status || true"]' \
  --query 'Command.CommandId' --output text)

sleep 2
aws ssm get-command-invocation \
  --region "${REGION}" \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}" \
  --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' --output json

if [[ -n "${PUBLIC_IP}" && "${PUBLIC_IP}" != "None" ]]; then
  echo "[info] probing http://${PUBLIC_IP}:18789/health (best effort)"
  set +e
  curl -m 5 -sS "http://${PUBLIC_IP}:18789/health" >/tmp/openclaw_health_probe.out
  RC=$?
  set -e
  if [[ $RC -ne 0 ]]; then
    echo "[warn] direct public probe failed (expected for loopback/no-ingress topology)"
  else
    echo "[info] direct public probe succeeded"
    cat /tmp/openclaw_health_probe.out
  fi
fi

echo "[ok] smoke checks completed"
