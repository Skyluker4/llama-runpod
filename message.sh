#!/bin/bash

if [ $# -lt 2 ]; then
  echo "Usage: $0 <port> <message>"
  exit 1
fi

PORT="$1"
shift
MESSAGE="$*"

curl -k "https://glm5-runpod:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"unsloth/GLM-5\",
    \"messages\": [
      {\"role\": \"user\", \"content\": $(printf '%s' "$MESSAGE" | jq -Rs .)}
    ]
  }"
