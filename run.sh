#!/bin/bash
set -e

SSL_DIR="/etc/nginx/ssl"
SSL_CERT_PATH="${SSL_DIR}/server.crt"
SSL_KEY_PATH="${SSL_DIR}/server.key"

# ── Provision TLS certificate ──
mkdir -p "$SSL_DIR"

if [ -n "$SSL_CERT" ] && [ -n "$SSL_KEY" ]; then
    echo "Using SSL cert/key from environment variables"
    echo "$SSL_CERT" > "$SSL_CERT_PATH"
    echo "$SSL_KEY" > "$SSL_KEY_PATH"
elif [ -n "$SSL_CERT_FILE" ] && [ -n "$SSL_KEY_FILE" ] && [ -f "$SSL_CERT_FILE" ] && [ -f "$SSL_KEY_FILE" ]; then
    echo "Using SSL cert/key from files: ${SSL_CERT_FILE}, ${SSL_KEY_FILE}"
    cp "$SSL_CERT_FILE" "$SSL_CERT_PATH"
    cp "$SSL_KEY_FILE" "$SSL_KEY_PATH"
else
    echo "No SSL cert provided — generating self-signed certificate..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
        -keyout "$SSL_KEY_PATH" \
        -out "$SSL_CERT_PATH" \
        -subj "/CN=glm5-runpod" 2>/dev/null
    echo "===== SELF-SIGNED PUBLIC CERTIFICATE ====="
    cat "$SSL_CERT_PATH"
    echo "==========================================="
fi
chmod 600 "$SSL_KEY_PATH"
chmod 644 "$SSL_CERT_PATH"

# ── Configuration (all overridable via environment variables) ──
QUANT="${QUANT:-UD-IQ2_XXS}"
CTX_SIZE="${CTX_SIZE:-202752}"
MIN_P="${MIN_P:-0.01}"
PORT="${PORT:-8001}"
GPU_LAYERS="${GPU_LAYERS:-99}"
THREADS="${THREADS:-$(nproc)}"

# ── Set temp / top-p based on TOOLS_ENABLED ──
if [ "$TOOLS_ENABLED" = "true" ]; then
    TEMP="${TEMP:-1.0}"
    TOP_P="${TOP_P:-0.95}"
else
    TEMP="${TEMP:-0.7}"
    TOP_P="${TOP_P:-1.0}"
fi

# ── Optional API key ──
EXTRA_ARGS=""
if [ -n "$API_KEY" ]; then
    EXTRA_ARGS="--api-key ${API_KEY}"
fi

echo "===== GLM-5 RunPod ====="
echo "  Quant:      ${QUANT}"
echo "  Context:    ${CTX_SIZE}"
echo "  Temp:       ${TEMP}"
echo "  Top-P:      ${TOP_P}"
echo "  Min-P:      ${MIN_P}"
echo "  GPU Layers: ${GPU_LAYERS}"
echo "  Port:       ${PORT}"
echo "  Threads:    ${THREADS}"
echo "  Tools:      ${TOOLS_ENABLED:-false}"
echo "========================="

# ── Start nginx TLS proxy ──
nginx
echo "nginx started on :443"

# ── Start llama-server (downloads the model automatically via -hf) ──
exec ./llama.cpp/llama-server \
    -hf "unsloth/GLM-5-GGUF:${QUANT}" \
    --alias "unsloth/GLM-5" \
    --host 127.0.0.1 \
    --port "$PORT" \
    --prio 3 \
    --temp "$TEMP" \
    --top-p "$TOP_P" \
    --min-p "$MIN_P" \
    --ctx-size "$CTX_SIZE" \
    --n-gpu-layers "$GPU_LAYERS" \
    --threads "$THREADS" \
    --flash-attn on \
    $EXTRA_ARGS
