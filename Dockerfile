FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

# Build llama.cpp with CUDA support, install nginx & generate self-signed cert
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential=12.10ubuntu1 \
        cmake=3.28.3-1build7 \
        curl=8.5.0-2ubuntu10.7 \
        libcap2-bin=1:2.66-5ubuntu2.2 \
        libcurl4-openssl-dev=8.5.0-2ubuntu10.7 \
        nginx=1.24.0-2ubuntu7.6 \
        openssl=3.0.13-0ubuntu3.7 \
        pciutils=1:3.10.0-2build1 && \
    git clone --branch b8140 --single-branch https://github.com/ggml-org/llama.cpp && \
    cmake llama.cpp -B llama.cpp/build -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON && \
    cmake --build llama.cpp/build --config Release -j --clean-first --target llama-cli llama-mtmd-cli llama-server llama-gguf-split && \
    cp llama.cpp/build/bin/llama-* llama.cpp && \
    rm -rf llama.cpp/build && \
    mkdir -p /etc/nginx/ssl && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    useradd -m -s /bin/sh llama && \
    setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx && \
    chown -R llama:llama /etc/nginx /var/log/nginx /var/lib/nginx /run llama.cpp

COPY --chown=llama:llama nginx-redirect.conf /etc/nginx/nginx-redirect.conf
COPY --chown=llama:llama nginx-allow-http.conf /etc/nginx/nginx-allow-http.conf
COPY --chmod=0755 run.sh /run.sh

ENV LLAMA_CACHE="/workspace/models"
ENV TOOLS_ENABLED=false

EXPOSE 80 443

USER llama

HEALTHCHECK --interval=30s --timeout=5s --start-period=600s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8001}/health || exit 1

CMD ["/run.sh"]
