#!/bin/sh

HOSTNAME="llama-runpod"

# Detect if first arg is an IP (contains a dot)
if [ $# -ge 3 ] && echo "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  IP="$1"
  shift

  # Detect privilege escalation tool
  if command -v sudo >/dev/null 2>&1; then
    PRIV="sudo"
  elif command -v doas >/dev/null 2>&1; then
    PRIV="doas"
  else
    echo "Error: sudo or doas required to update /etc/hosts" >&2
    exit 1
  fi

  # Update or add /etc/hosts entry
  if grep -q "$HOSTNAME" /etc/hosts 2>/dev/null; then
    $PRIV sed -i "s/.*${HOSTNAME}/${IP} ${HOSTNAME}/" /etc/hosts
  else
    echo "${IP} ${HOSTNAME}" | $PRIV tee -a /etc/hosts >/dev/null
  fi
  echo "Updated /etc/hosts: ${IP} → ${HOSTNAME}"
  HOST="$HOSTNAME"
else
  HOST="localhost"
fi

if [ $# -lt 2 ]; then
  echo "Usage: $0 [ip] <port> <message>"
  exit 1
fi

PORT="$1"
shift
MESSAGE="$*"

curl -k "https://${HOST}:${PORT}/v1/chat/completions" \
  -H "X-API-Key: $(cat key.txt)" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"unsloth/GLM-5\",
    \"messages\": [
      {\"role\": \"user\", \"content\": $(printf '%s' "$MESSAGE" | jq -Rs .)}
    ]
  }"
