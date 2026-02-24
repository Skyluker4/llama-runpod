FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

ENV LLAMA_CACHE="unsloth/GLM-5-GGUF" 
ENV TOOLS_ENABLED=false

RUN apt-get update \
	apt-get install pciutils build-essential cmake curl libcurl4-openssl-dev -y \
	git clone --branch b8140 --single-branch https://github.com/ggml-org/llama.cpp \
	cmake llama.cpp -B llama.cpp/build -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON \
	cmake --build llama.cpp/build --config Release -j --clean-first --target llama-cli llama-mtmd-cli llama-server llama-gguf-split \
	cp llama.cpp/build/bin/llama-* llama.cpp

COPY run.sh run.sh

CMD ./run.sh
