#!/bin/bash

# Установка Python и git
apt update && apt install -y python3 python3-pip git wget aria2 ffmpeg
ln -sf /usr/bin/python3 /usr/bin/python

# ComfyUI
cd /workspace
if [ ! -d "ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    pip install -r requirements.txt
fi

# Кастомные ноды
cd /workspace/ComfyUI/custom_nodes

if [ ! -d "ComfyUI-WanVideoWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
    cd ComfyUI-WanVideoWrapper && pip install -r requirements.txt && cd ..
fi

if [ ! -d "ComfyUI-Custom-Scripts" ]; then
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
fi

if [ ! -d "ComfyUI-KJNodes" ]; then
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
fi

if [ ! -d "ComfyUI-Easy-Use" ]; then
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git
fi

if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/fannovel16/ComfyUI-Frame-Interpolation.git
    cd ComfyUI-Frame-Interpolation && pip install -r requirements.txt && cd ..
fi

# Дополнительные пакеты
pip install opencv-python accelerate gguf

# Папки для моделей
mkdir -p /workspace/ComfyUI/models/diffusion_models
mkdir -p /workspace/ComfyUI/models/text_encoders
mkdir -p /workspace/ComfyUI/models/vae
mkdir -p /workspace/ComfyUI/models/loras
mkdir -p /workspace/ComfyUI/models/rife
mkdir -p /workspace/ComfyUI/input
mkdir -p /workspace/ComfyUI/output

# ============================================
# СКАЧИВАНИЕ МОДЕЛЕЙ
# ============================================

cd /workspace/ComfyUI/models/diffusion_models
wget -O Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors?download=1"
wget -O Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors?download=1"

cd /workspace/ComfyUI/models/text_encoders
wget -O nsfw_wan_umt5-xxl_fp8_scaled.safetensors "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors?download=1"

cd /workspace/ComfyUI/models/vae
wget -O wan_2.1_vae.safetensors "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=1"

cd /workspace/ComfyUI/models/loras
wget -O Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors?download=1"
wget -O Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors?download=1"

cd /workspace/ComfyUI/models/rife
wget -O rife47.pth "https://huggingface.co/jasonot/mycomfyui/resolve/main/rife47.pth?download=1"

# Запуск ComfyUI
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188
