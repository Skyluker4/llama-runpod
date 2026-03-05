# llama-server RunPod

[![Deploy on RunPod](https://www.runpod.io/console/deploy-badge.svg)](https://console.runpod.io/deploy?template=9971n7l71b&ref=23r2887x)
[![Docker Hub](https://img.shields.io/docker/v/skyluker4/llama-runpod?sort=semver&logo=docker&label=Docker%20Hub)](https://hub.docker.com/r/skyluker4/llama-runpod)
[![GHCR](https://img.shields.io/badge/GHCR-skyluker4%2Fllama--runpod-blue?logo=github)](https://ghcr.io/skyluker4/llama-runpod)
[![Quay.io](https://img.shields.io/badge/Quay.io-skyluker4%2Fllama--runpod-blue?logo=red-hat)](https://quay.io/repository/skyluker4/llama-runpod)

Deploy GGUF models on [RunPod](https://www.runpod.io/) using [llama.cpp](https://github.com/ggml-org/llama.cpp) with an OpenAI-compatible API served over HTTPS.

Defaults to [GLM-5](https://unsloth.ai/docs/models/glm-5) by Z.ai (744B parameters, 40B active, 200K context window) via [Unsloth Dynamic 2.0 GGUFs](https://huggingface.co/unsloth/GLM-5-GGUF), but any GGUF model on Hugging Face or on disk can be used.

## Architecture

```text
Client ──HTTPS:443──▶ nginx (TLS termination) ──HTTP:8001──▶ llama-server
                      │
               HTTP:80 → 301 redirect to HTTPS (or proxy, if ALLOW_HTTP=true)
```

- **nginx** terminates TLS (Mozilla modern config, TLS 1.3 only) and proxies to llama-server
- **llama-server** serves an OpenAI-compatible API on `localhost:8001` (not exposed externally)
- HF models are downloaded automatically on first startup via llama.cpp's built-in `-hf` flag

## Quick Start

### Default (GLM-5)

```sh
docker build -t llama-runpod .
docker run --gpus all -p 443:443 llama-runpod
```

### Any Hugging Face GGUF

```sh
docker run --gpus all -p 443:443 \
  -e HF_MODEL="bartowski/Qwen3-32B-GGUF:Q4_K_M" \
  -e CTX_SIZE=40960 \
  llama-runpod
```

### Local model file

```sh
docker run --gpus all -p 443:443 \
  -v /path/to/models:/models \
  -e MODEL_PATH="/models/my-model.gguf" \
  llama-runpod
```

On first launch with an HF model, the weights are downloaded and cached to `/workspace/models`. Attach a persistent volume there to avoid re-downloading.

## Environment Variables

### Model Source

The model is resolved in this order of priority:

| Variable      | Default      | Description                                                                                                                |
| ------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `MODEL_PATH`  | _(unset)_    | Path to a local GGUF file — used as `--model`                                                                              |
| `HF_MODEL`    | _(unset)_    | Hugging Face `repo:quant` string — used as `-hf`                                                                           |
| `QUANT`       | `UD-IQ2_XXS` | Quantization variant (only used when neither `MODEL_PATH` nor `HF_MODEL` is set, defaults to `unsloth/GLM-5-GGUF:<QUANT>`) |
| `MODEL_ALIAS` | _(auto)_     | OpenAI-compatible model name returned in API responses. Auto-derived from the model source if unset                        |

### Inference

| Variable     | Default        | Description                                  |
| ------------ | -------------- | -------------------------------------------- |
| `CTX_SIZE`   | `202752`       | Maximum context window                       |
| `GPU_LAYERS` | `99`           | Number of layers offloaded to GPU (99 = all) |
| `THREADS`    | auto (`nproc`) | CPU threads                                  |
| `PORT`       | `8001`         | Internal llama-server port                   |

### Sampling

| Variable        | Default  | Description                                                                                                             |
| --------------- | -------- | ----------------------------------------------------------------------------------------------------------------------- |
| `TOOLS_ENABLED` | `false`  | When `true`, uses temp=1.0 / top_p=0.95 (tool-calling preset). When `false`, uses temp=0.7 / top_p=1.0 (general preset) |
| `TEMP`          | per mode | Override temperature directly                                                                                           |
| `TOP_P`         | per mode | Override top-p directly                                                                                                 |
| `MIN_P`         | `0.01`   | Minimum probability threshold                                                                                           |

### Security

| Variable           | Default   | Description                                                                                                |
| ------------------ | --------- | ---------------------------------------------------------------------------------------------------------- |
| `API_KEY`          | _(unset)_ | If set, llama-server requires this as a Bearer token                                                       |
| `GENERATE_API_KEY` | `false`   | When `true` and `API_KEY` is unset, generates a random 48-character key at startup and prints it to stdout |
| `SSL_CERT`         | _(unset)_ | Base64-encoded PEM certificate (`base64 -w0 < server.crt`)                                                 |
| `SSL_KEY`          | _(unset)_ | Base64-encoded PEM private key (`base64 -w0 < server.key`)                                                 |
| `SSL_CERT_FILE`    | _(unset)_ | Path to a certificate file                                                                                 |
| `SSL_KEY_FILE`     | _(unset)_ | Path to a private key file                                                                                 |

### Networking

| Variable     | Default | Description                                                                   |
| ------------ | ------- | ----------------------------------------------------------------------------- |
| `ALLOW_HTTP` | `false` | When `true`, port 80 proxies traffic directly instead of redirecting to HTTPS |

### TLS Certificate Priority

1. **`SSL_CERT` + `SSL_KEY`** — base64-decoded and written to disk from env vars
2. **`SSL_CERT_FILE` + `SSL_KEY_FILE`** — existing files copied into place
3. **Fallback** — a self-signed certificate (RSA 4096, 10-year expiry) is generated at startup and the public certificate is printed to stdout

## Usage

### With the OpenAI Python client

```sh
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

### With cURL

```sh
curl -k https://localhost/v1/chat/completions \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "unsloth/GLM-5",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### With message.sh

```sh
./message.sh 443 "Hello!"
./message.sh 443 "Create a Snake game."
```

## GLM-5 Recommended Settings

From the [official docs](https://unsloth.ai/docs/models/glm-5):

| Use Case                 | Temperature | Top-P | Min-P | Max Tokens |
| ------------------------ | ----------- | ----- | ----- | ---------- |
| General (default)        | 0.7         | 1.0   | 0.01  | 131072     |
| SWE Bench / Tool Calling | 1.0         | 0.95  | 0.01  | 16384      |

## Health Check

The container includes a Docker `HEALTHCHECK` that polls llama-server's `/health` endpoint:

- **Interval:** 30s
- **Timeout:** 5s
- **Start period:** 600s (allows time for model download)
- **Retries:** 3

## Files

| File                    | Purpose                                                                         |
| ----------------------- | ------------------------------------------------------------------------------- |
| `Dockerfile`            | Builds llama.cpp with CUDA, installs nginx + OpenSSL                            |
| `run.sh`                | Provisions TLS cert, resolves model source, starts nginx, launches llama-server |
| `nginx-redirect.conf`   | Mozilla modern TLS config, HTTP→HTTPS redirect, reverse proxy                   |
| `nginx-allow-http.conf` | Same as above but serves HTTP traffic directly on port 80                       |
| `message.sh`            | Quick cURL helper — takes port and message as arguments                         |

## GLM-5 Memory Requirements

| Quantization         | Disk Size | Minimum Memory (VRAM + RAM) |
| -------------------- | --------- | --------------------------- |
| `UD-TQ1_0` (1-bit)   | 176 GB    | ~180 GB                     |
| `UD-IQ2_XXS` (2-bit) | 241 GB    | ~256 GB                     |
| `UD-Q4_K_XL` (4-bit) | ~400 GB   | ~420 GB                     |
| `UD-Q8_0` (8-bit)    | ~805 GB   | ~820 GB                     |

Total available memory (VRAM + system RAM) should exceed the model file size. llama.cpp can fall back to disk offloading if it doesn't, but inference will be slower.

## License

This project is licensed under the [GNU Affero General Public License v3.0 only (AGPL-3.0-only)](LICENSE).

Model weights are subject to their respective license terms. See [unsloth/GLM-5-GGUF](https://huggingface.co/unsloth/GLM-5-GGUF) for GLM-5 details.
