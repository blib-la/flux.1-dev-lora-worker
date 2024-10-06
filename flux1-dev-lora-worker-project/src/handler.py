import os
import json
import requests
import runpod
import random
import time
import torch
import numpy as np
from PIL import Image

import base64
import sys

sys.path.append("/content/ComfyUI")

import nodes
from nodes import NODE_CLASS_MAPPINGS
from comfy_extras import nodes_custom_sampler
from comfy_extras import nodes_flux
from comfy import model_management

# Initialize Model Loaders
DualCLIPLoader = NODE_CLASS_MAPPINGS["DualCLIPLoader"]()
UNETLoader = NODE_CLASS_MAPPINGS["UNETLoader"]()
VAELoader = NODE_CLASS_MAPPINGS["VAELoader"]()

LoraLoader = NODE_CLASS_MAPPINGS["LoraLoader"]()
FluxGuidance = nodes_flux.NODE_CLASS_MAPPINGS["FluxGuidance"]()
RandomNoise = nodes_custom_sampler.NODE_CLASS_MAPPINGS["RandomNoise"]()
BasicGuider = nodes_custom_sampler.NODE_CLASS_MAPPINGS["BasicGuider"]()
KSamplerSelect = nodes_custom_sampler.NODE_CLASS_MAPPINGS["KSamplerSelect"]()
BasicScheduler = nodes_custom_sampler.NODE_CLASS_MAPPINGS["BasicScheduler"]()
SamplerCustomAdvanced = nodes_custom_sampler.NODE_CLASS_MAPPINGS[
    "SamplerCustomAdvanced"
]()
VAEDecode = NODE_CLASS_MAPPINGS["VAEDecode"]()
EmptyLatentImage = NODE_CLASS_MAPPINGS["EmptyLatentImage"]()

with torch.inference_mode():
    clip = DualCLIPLoader.load_clip(
        "t5xxl_fp16.safetensors", "clip_l.safetensors", "flux"
    )[0]
    unet = UNETLoader.load_unet("flux1-dev.sft", "default")[0]
    vae = VAELoader.load_vae("ae.sft")[0]


def closestNumber(n, m):
    q = int(n / m)
    n1 = m * q
    if (n * m) > 0:
        n2 = m * (q + 1)
    else:
        n2 = m * (q - 1)
    if abs(n - n1) < abs(n - n2):
        return n1
    return n2


@torch.inference_mode()
def generate(input):
    values = input["input"]

    positive_prompt = values.get("positive_prompt", "")
    width = values.get("width", 512)
    height = values.get("height", 512)
    seed = values.get("seed", 0)
    steps = values.get("steps", 50)
    guidance = values.get("guidance", 7.5)
    lora_strength_model = values.get("lora_strength_model", 0.8)
    lora_strength_clip = values.get("lora_strength_clip", 0.8)
    sampler_name = values.get("sampler_name", "Euler")
    scheduler = values.get("scheduler", "default")
    job_id = values.get("job_id", "test-job-123")
    lora_name = values.get("lora_name", "zanshou-kin-flux-ueno-manga-style.safetensors")

    # Path to the LoRA model based on lora_name
    lora_file_path = f"models/loras/{lora_name}"

    # Validate if the specified LoRA model exists
    if not os.path.exists(lora_file_path):
        error_response = {
            "jobId": job_id,
            "result": f"FAILED: LoRA model '{lora_name}' not found.",
            "status": "FAILED",
        }
        print(
            f"Error: LoRA model '{lora_name}' does not exist at path '{lora_file_path}'."
        )
        return error_response

    # Handle seed
    if seed == 0:
        random.seed(int(time.time()))
        seed = random.randint(0, 18446744073709551615)
    print(f"Using seed: {seed}")

    try:
        # Load LoRA models from the specified file
        unet_lora, clip_lora = LoraLoader.load_lora(
            unet, clip, lora_file_path, lora_strength_model, lora_strength_clip
        )

        # Encode the positive prompt
        cond, pooled = clip_lora.encode_from_tokens(
            clip_lora.tokenize(positive_prompt), return_pooled=True
        )
        cond = [[cond, {"pooled_output": pooled}]]
        cond = FluxGuidance.append(cond, guidance)[0]

        # Generate noise based on the seed
        noise = RandomNoise.get_noise(seed)[0]

        # Initialize the guider and sampler
        guider = BasicGuider.get_guider(unet_lora, cond)[0]
        sampler = KSamplerSelect.get_sampler(sampler_name)[0]
        sigmas = BasicScheduler.get_sigmas(unet_lora, scheduler, steps, 1.0)[0]

        # Generate an empty latent image
        latent_image = EmptyLatentImage.generate(
            closestNumber(width, 16), closestNumber(height, 16)
        )[0]

        # Perform the sampling
        sample, sample_denoised = SamplerCustomAdvanced.sample(
            noise, guider, sampler, sigmas, latent_image
        )

        # Decode the image using VAE
        decoded = VAEDecode.decode(vae, sample)[0].detach()

        # Save the image to a file
        image_path = "flux.png"
        Image.fromarray(np.array(decoded * 255, dtype=np.uint8)[0]).save(image_path)

        # Open and encode the image in Base64
        with open(image_path, "rb") as image_file:
            encoded_image = base64.b64encode(image_file.read()).decode("utf-8")

        # Prepare the response
        response = {"jobId": job_id, "image": encoded_image, "status": "DONE"}
        return response

    except Exception as e:
        error_response = {
            "jobId": job_id,
            "result": f"FAILED: {str(e)}",
            "status": "FAILED",
        }
        print(f"Error processing job {job_id}: {str(e)}")
        return error_response

    finally:
        # Clean up the generated image file
        if os.path.exists(image_path):
            os.remove(image_path)


runpod.serverless.start({"handler": generate})
