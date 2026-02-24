#!/bin/bash

if -n blah; then
	# General Instruction
	RUN ./llama.cpp/llama-cli -hf unsloth/GLM-5-GGUF:UD-IQ2_XXS --ctx-size 16384 --flash-attn on --temp 0.7 --top-p 1.0 --min-p 0.01
	# Tool Calling
	#RUN ./llama.cpp/llama-cli -hf unsloth/GLM-5-GGUF:UD-IQ2_XXS --ctx-size 16384 --flash-attn on --temp 1.0 --top-p 0.95 --min-p 0.01
endif

CMD ./llama.cpp/llama-cli --api-key "${API_KEY}" --model unsloth/GLM-5-GGUF/UD-IQ2_XXS/GLM-5-UD-IQ2_XXS-00001-of-00006.gguf --alias "unsloth/GLM-5" --prio 3 --temp 1.0 --top-p 0.95 --ctx-size 16384 --port 8001
