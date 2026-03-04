#!/bin/sh
set -e

ALLOW_HTTP="${ALLOW_HTTP:-false}"
HF_MODEL="${HF_MODEL:-}"
MODEL_PATH="${MODEL_PATH:-}"
MODEL_ALIAS="${MODEL_ALIAS:-}"
SSL_DIR="/etc/nginx/ssl"
SSL_CERT_PATH="${SSL_DIR}/server.crt"
SSL_KEY_PATH="${SSL_DIR}/server.key"

# ── Provision TLS certificate ──
mkdir -p "$SSL_DIR"

if [ -n "$SSL_CERT" ] && [ -n "$SSL_KEY" ]; then
	echo "Using SSL cert/key from environment variables (base64)"
	printf '%s' "$SSL_CERT" | base64 -d >"$SSL_CERT_PATH"
	printf '%s' "$SSL_KEY" | base64 -d >"$SSL_KEY_PATH"
elif [ -n "$SSL_CERT_FILE" ] && [ -n "$SSL_KEY_FILE" ] && [ -f "$SSL_CERT_FILE" ] && [ -f "$SSL_KEY_FILE" ]; then
	echo "Using SSL cert/key from files: ${SSL_CERT_FILE}, ${SSL_KEY_FILE}"
	cp "$SSL_CERT_FILE" "$SSL_CERT_PATH"
	cp "$SSL_KEY_FILE" "$SSL_KEY_PATH"
else
	echo "No SSL cert provided — generating self-signed certificate..."
	openssl req -x509 -nodes -days 90 -newkey rsa:4096 \
		-keyout "$SSL_KEY_PATH" \
		-out "$SSL_CERT_PATH" \
		-subj "/CN=llama-runpod" 2>/dev/null
	echo "===== SELF-SIGNED PUBLIC CERTIFICATE ====="
	cat "$SSL_CERT_PATH"
	echo "==========================================="
fi
chmod 600 "$SSL_KEY_PATH"
chmod 644 "$SSL_CERT_PATH"

# ── Configuration (all overridable via environment variables) ──
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

# ── API key ──
if [ -z "$API_KEY" ] && [ "$GENERATE_API_KEY" = "true" ]; then
	API_KEY=$(head -c 48 /dev/urandom | base64 | tr -d '/+=' | head -c 48)
	echo "===== GENERATED API KEY ====="
	echo "  $API_KEY"
	echo "============================="
fi

EXTRA_ARGS=""
if [ -n "$API_KEY" ]; then
	EXTRA_ARGS="--api-key ${API_KEY}"
fi

# ── Resolve model source ──
if [ -n "$MODEL_PATH" ]; then
	MODEL_SRC="--model ${MODEL_PATH}"
	MODEL_ALIAS="${MODEL_ALIAS:-$(basename "$MODEL_PATH" .gguf)}"
elif [ -n "$HF_MODEL" ]; then
	MODEL_SRC="-hf ${HF_MODEL}"
	MODEL_ALIAS="${MODEL_ALIAS:-${HF_MODEL%%:*}}"
else
	QUANT="${QUANT:-UD-IQ2_XXS}"
	MODEL_SRC="-hf unsloth/GLM-5-GGUF:${QUANT}"
	MODEL_ALIAS="${MODEL_ALIAS:-unsloth/GLM-5}"
fi

echo "===== llama-server RunPod ====="
echo "  Model:      ${MODEL_SRC}"
echo "  Alias:      ${MODEL_ALIAS}"
echo "  Context:    ${CTX_SIZE}"
echo "  Temp:       ${TEMP}"
echo "  Top-P:      ${TOP_P}"
echo "  Min-P:      ${MIN_P}"
echo "  GPU Layers: ${GPU_LAYERS}"
echo "  Port:       ${PORT}"
echo "  Threads:    ${THREADS}"
echo "  Tools:      ${TOOLS_ENABLED:-false}"
echo "  Allow HTTP: ${ALLOW_HTTP}"
echo "================================"

# ── Select nginx config based on ALLOW_HTTP ──
if [ "$ALLOW_HTTP" = "true" ]; then
	cp /etc/nginx/nginx-allow-http.conf /etc/nginx/nginx.conf
	echo "nginx: plain HTTP enabled on :80"
else
	cp /etc/nginx/nginx-redirect.conf /etc/nginx/nginx.conf
	echo "nginx: HTTP :80 redirects to HTTPS"
fi

# ── Start nginx TLS proxy ──
nginx
echo "nginx started on :443"

# ── Start llama-server ──
# shellcheck disable=SC2086
exec ./llama.cpp/llama-server \
	$MODEL_SRC \
	--alias "$MODEL_ALIAS" \
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
