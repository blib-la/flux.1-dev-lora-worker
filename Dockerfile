FROM runpod/pytorch:2.2.1-py3.10-cuda12.1.1-devel-ubuntu22.04
WORKDIR /content
ENV PATH="/home/camenduru/.local/bin:${PATH}"

# Add and configure the 'camenduru' user
RUN adduser --disabled-password --gecos '' camenduru && \
    adduser camenduru sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R camenduru:camenduru /content && \
    chmod -R 777 /content && \
    chown -R camenduru:camenduru /home && \
    chmod -R 777 /home && \
    apt update -y && \
    add-apt-repository -y ppa:git-core/ppa && \
    apt update -y && \
    apt install -y aria2 git git-lfs unzip ffmpeg

USER camenduru

# Install Python dependencies, clone ComfyUI, and download necessary models & LoRA
RUN pip install -q opencv-python imageio imageio-ffmpeg ffmpeg-python av runpod \
    xformers==0.0.25 torchsde==0.2.6 einops==0.8.0 diffusers==0.28.0 transformers==4.41.2 accelerate==0.30.1 && \
    git clone https://github.com/comfyanonymous/ComfyUI /content/ComfyUI && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M \
        https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/flux1-dev.sft -d /content/ComfyUI/models/unet -o flux1-dev.sft && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M \
        https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/clip_l.safetensors -d /content/ComfyUI/models/clip -o clip_l.safetensors && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M \
        https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/t5xxl_fp16.safetensors -d /content/ComfyUI/models/clip -o t5xxl_fp16.safetensors && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M \
        https://huggingface.co/camenduru/FLUX.1-dev/resolve/main/ae.sft -d /content/ComfyUI/models/vae -o ae.sft && \
    mkdir -p /content/ComfyUI/models/loras && \
    aria2c --console-log-level=error -c -x 16 -s 16 -k 1M \
        https://civitai.com/api/download/models/896422?type=Model&format=SafeTensor -d /content/ComfyUI/models/loras -o zanshou-kin-flux-ueno-manga-style.safetensors

# Copy the updated worker script into the container
COPY ./worker_runpod.py /content/ComfyUI/worker_runpod.py

WORKDIR /content/ComfyUI

# Define the command to run the worker
CMD python worker_runpod.py
