FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

ENV LLAMA_CACHE="/workspace/unsloth/GLM-5-GGUF"
ENV TOOLS_ENABLED=false

# Build llama.cpp with CUDA support, install nginx & generate self-signed cert
RUN apt-get update && \
    apt-get install -y pciutils build-essential cmake curl libcurl4-openssl-dev nginx openssl && \
    git clone --branch b8140 --single-branch https://github.com/ggml-org/llama.cpp && \
    cmake llama.cpp -B llama.cpp/build -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON && \
    cmake --build llama.cpp/build --config Release -j --clean-first --target llama-cli llama-mtmd-cli llama-server llama-gguf-split && \
    cp llama.cpp/build/bin/llama-* llama.cpp && \
    rm -rf llama.cpp/build && \
    mkdir -p /etc/nginx/ssl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY nginx.conf /etc/nginx/nginx.conf
COPY --chmod=0755 run.sh /run.sh

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=5s --start-period=600s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8001}/health || exit 1

CMD ["/run.sh"]
