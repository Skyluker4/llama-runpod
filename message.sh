#!/bin/sh

HOSTNAME="llama-runpod"

if [ $# -lt 2 ]; then
  echo "Usage: $0 [ip:]<port> <message>"
  echo ""
  echo "Examples:"
  echo "  $0 443 Hello!"
  echo "  $0 192.168.1.50:443 Hello!"
  exit 1
fi

# Parse first arg as [ip:]port
case "$1" in
  *:*)
    IP="${1%%:*}"
    PORT="${1##*:}"
    ;;
  *)
    IP=""
    PORT="$1"
    ;;
esac
shift
MESSAGE="$*"

RESOLVE_ARG=""
if [ -n "$IP" ]; then
  HOST="$HOSTNAME"
  RESOLVE_ARG="--resolve ${HOSTNAME}:${PORT}:${IP}"
else
  HOST="$HOSTNAME"
fi

curl -k $RESOLVE_ARG "https://${HOST}:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"unsloth/GLM-5\",
    \"messages\": [
      {\"role\": \"user\", \"content\": $(printf '%s' "$MESSAGE" | jq -Rs .)}
    ]
  }"
