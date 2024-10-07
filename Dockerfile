# Use RunPod's base image
FROM runpod/base:0.6.1-cuda12.2.0

# Only install absolutely necessary packages for your project
RUN apt-get update && apt-get install -y ffmpeg aria2 git unzip

# Clone the ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI /content/ComfyUI

# Download required model files
RUN mkdir -p /content/ComfyUI/models/unet && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M "https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/flux1-dev.sft" -d /content/ComfyUI/models/unet -o flux1-dev.sft && \
    mkdir -p /content/ComfyUI/models/clip && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M "https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/clip_l.safetensors" -d /content/ComfyUI/models/clip -o clip_l.safetensors && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M "https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/t5xxl_fp16.safetensors" -d /content/ComfyUI/models/clip -o t5xxl_fp16.safetensors && \
    mkdir -p /content/ComfyUI/models/vae && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M "https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/ae.sft" -d /content/ComfyUI/models/vae -o ae.sft && \
    mkdir -p /content/ComfyUI/models/loras && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M "https://civitai.com/api/download/models/896422?type=Model&format=SafeTensor" -d /content/ComfyUI/models/loras -o zanshou-kin-flux-ueno-manga-style.safetensors

# Reset the working directory to the base image's root
WORKDIR /

# Keep the base image's entrypoint
CMD ["/start.sh"]
