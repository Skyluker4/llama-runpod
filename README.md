# GLM-5 RunPod

Deploy [GLM-5](https://unsloth.ai/docs/models/glm-5) on [RunPod](https://www.runpod.io/) using [llama.cpp](https://github.com/ggml-org/llama.cpp) with an OpenAI-compatible API served over HTTPS.

GLM-5 is Z.ai's latest reasoning model (744B parameters, 40B active) with a 200K context window. This container serves [Unsloth Dynamic 2.0 GGUFs](https://huggingface.co/unsloth/GLM-5-GGUF) via `llama-server` behind an nginx TLS reverse proxy.

## Architecture

```
Client ──HTTPS:443──▶ nginx (TLS termination) ──HTTP:8001──▶ llama-server
                      │
               HTTP:80 → 301 redirect to HTTPS
```

- **nginx** terminates TLS (Mozilla modern config, TLS 1.3 only) and proxies to llama-server
- **llama-server** serves an OpenAI-compatible API on `localhost:8001` (not exposed externally)
- The model is downloaded automatically on first startup via llama.cpp's built-in `-hf` flag

## Environment Variables

### Model & Inference

| Variable | Default | Description |
|---|---|---|
| `QUANT` | `UD-IQ2_XXS` | Quantization variant from [unsloth/GLM-5-GGUF](https://huggingface.co/unsloth/GLM-5-GGUF) |
| `CTX_SIZE` | `202752` | Maximum context window (model max is 202,752) |
| `GPU_LAYERS` | `99` | Number of layers offloaded to GPU (99 = all) |
| `THREADS` | auto (`nproc`) | CPU threads for inference |
| `PORT` | `8001` | Internal llama-server port |

### Sampling

| Variable | Default | Description |
|---|---|---|
| `TOOLS_ENABLED` | `false` | When `true`, uses temp=1.0 / top_p=0.95 (tool-calling preset). When `false`, uses temp=0.7 / top_p=1.0 (general preset) |
| `TEMP` | per mode | Override temperature directly |
| `TOP_P` | per mode | Override top-p directly |
| `MIN_P` | `0.01` | Minimum probability threshold |

### Security

| Variable | Default | Description |
|---|---|---|
| `API_KEY` | *(unset)* | If set, llama-server requires this as a Bearer token |
| `SSL_CERT` | *(unset)* | Inline PEM certificate content |
| `SSL_KEY` | *(unset)* | Inline PEM private key content |
| `SSL_CERT_FILE` | *(unset)* | Path to a certificate file |
| `SSL_KEY_FILE` | *(unset)* | Path to a private key file |

### TLS Certificate Priority

1. **`SSL_CERT` + `SSL_KEY`** — PEM content written to disk from env vars
2. **`SSL_CERT_FILE` + `SSL_KEY_FILE`** — existing files copied into place
3. **Fallback** — a self-signed certificate (RSA 4096, 10-year expiry) is generated at startup and the public certificate is printed to stdout

## Usage

### With the OpenAI Python client

```
pip install openai
```

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://<your-runpod-host>/v1",
    api_key="your-api-key",  # or "sk-no-key-required" if API_KEY is unset
)

completion = client.chat.completions.create(
    model="unsloth/GLM-5",
    messages=[{"role": "user", "content": "Create a Snake game."}],
)
print(completion.choices[0].message.content)
```

> If using the self-signed certificate, pass `http_client` with `verify=False` or point `SSL_CERT_FILE` at the printed certificate.

### With curl

```
curl -k https://localhost/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "unsloth/GLM-5",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Recommended Settings

From the [official docs](https://unsloth.ai/docs/models/glm-5):

| Use Case | Temperature | Top-P | Min-P | Max Tokens |
|---|---|---|---|---|
| General (default) | 0.7 | 1.0 | 0.01 | 131072 |
| SWE Bench / Tool Calling | 1.0 | 0.95 | 0.01 | 16384 |

## Health Check

The container includes a Docker `HEALTHCHECK` that polls llama-server's `/health` endpoint:

- **Interval:** 30s
- **Timeout:** 5s
- **Start period:** 600s (allows time for model download)
- **Retries:** 3

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builds llama.cpp with CUDA, installs nginx + openssl |
| `run.sh` | Provisions TLS cert, starts nginx, launches llama-server |
| `nginx.conf` | Mozilla modern TLS config, HTTP→HTTPS redirect, reverse proxy |

## Memory Requirements

| Quantization | Disk Size | Minimum Memory (VRAM + RAM) |
|---|---|---|
| `UD-TQ1_0` (1-bit) | 176 GB | ~180 GB |
| `UD-IQ2_XXS` (2-bit) | 241 GB | ~256 GB |
| `UD-Q4_K_XL` (4-bit) | ~400 GB | ~420 GB |
| `UD-Q8_0` (8-bit) | ~805 GB | ~820 GB |

Total available memory (VRAM + system RAM) should exceed the model file size. llama.cpp can fall back to disk offloading if it doesn't, but inference will be slower.

## License

Model weights are subject to Z.ai's license terms. See [unsloth/GLM-5-GGUF](https://huggingface.co/unsloth/GLM-5-GGUF) for details.
