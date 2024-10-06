# Use RunPod's base image
FROM runpod/base:0.6.1-cuda12.2.0

# Set custom working directory for your code
WORKDIR /content/ComfyUI

# Add and configure the 'camenduru' user
RUN adduser --disabled-password --gecos '' camenduru && \
    adduser camenduru sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R camenduru:camenduru /content && \
    chmod -R 755 /content && \
    apt-get update && apt-get install -y aria2 git git-lfs unzip ffmpeg

# Switch to the 'camenduru' user
USER camenduru

# Install necessary Python dependencies
RUN pip install --no-cache-dir opencv-python imageio imageio-ffmpeg ffmpeg-python av runpod \
    xformers==0.0.25 torchsde==0.2.6 einops==0.8.0 diffusers==0.28.0 transformers==4.41.2 accelerate==0.30.1

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

# Reset the working directory to where the original start.sh is located
WORKDIR /