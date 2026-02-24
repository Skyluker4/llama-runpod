#!/bin/bash
set -e

# ── Configuration (all overridable via environment variables) ──
QUANT="${QUANT:-UD-IQ2_XXS}"
CTX_SIZE="${CTX_SIZE:-16384}"
MIN_P="${MIN_P:-0.01}"
PORT="${PORT:-8001}"
GPU_LAYERS="${GPU_LAYERS:-99}"

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
echo "  Tools:      ${TOOLS_ENABLED:-false}"
echo "========================="

# ── Start llama-server (downloads the model automatically via -hf) ──
exec ./llama.cpp/llama-server \
    -hf "unsloth/GLM-5-GGUF:${QUANT}" \
    --alias "unsloth/GLM-5" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --prio 3 \
    --temp "$TEMP" \
    --top-p "$TOP_P" \
    --min-p "$MIN_P" \
    --ctx-size "$CTX_SIZE" \
    --n-gpu-layers "$GPU_LAYERS" \
    --flash-attn \
    $EXTRA_ARGS
