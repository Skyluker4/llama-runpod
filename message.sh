#!/bin/sh

HOSTNAME="llama-runpod"
RESOLVE_ARG=""

# Detect if first arg is an IP (contains a dot)
if [ $# -ge 3 ] && echo "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  IP="$1"
  shift
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

if [ -n "$IP" ]; then
  RESOLVE_ARG="--resolve ${HOSTNAME}:${PORT}:${IP}"
fi

curl -k $RESOLVE_ARG "https://${HOST}:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"unsloth/GLM-5\",
    \"messages\": [
      {\"role\": \"user\", \"content\": $(printf '%s' "$MESSAGE" | jq -Rs .)}
    ]
  }"
