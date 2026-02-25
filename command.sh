curl --cacert server.crt -- https://something/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: ttvJRwJjEKUwximX3ZhoZLTKzZ9QrCc" \
  -d '{
    "model": "unsloth/glm-5",
    "max_tokens": 1024,
    "system": "You are a helpful assistant.",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
