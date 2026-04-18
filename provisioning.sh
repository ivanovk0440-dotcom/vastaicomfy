#!/bin/bash
set -e

echo "=== Starting provisioning ==="
cd /workspace/ComfyUI

# Создаём папки для моделей
mkdir -p models/wan
mkdir -p models/text_encoders
mkdir -p models/vae
mkdir -p models/loras
mkdir -p models/rife

# Скачиваем VAE
echo "=== Downloading VAE ==="
if [ ! -f "models/vae/wan_2.1_vae.safetensors" ]; then
    wget -O models/vae/wan_2.1_vae.safetensors \
        https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors
fi

# Скачиваем Text Encoder
echo "=== Downloading Text Encoder ==="
if [ ! -f "models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    wget -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors \
        https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors
fi

# Скачиваем основную модель HIGH lighting
echo "=== Downloading Wan model HIGH lighting ==="
if [ ! -f "models/wan/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" ]; then
    wget -O models/wan/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors \
        https://huggingface.co/Kijai/Wan2.2_Remix_NSFW/resolve/main/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors
fi

# Скачиваем основную модель LOW lighting
echo "=== Downloading Wan model LOW lighting ==="
if [ ! -f "models/wan/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" ]; then
    wget -O models/wan/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors \
        https://huggingface.co/Kijai/Wan2.2_Remix_NSFW/resolve/main/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors
fi

# Скачиваем LoRA HIGH
echo "=== Downloading LoRA HIGH ==="
if [ ! -f "models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" ]; then
    wget -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors \
        https://huggingface.co/Kijai/Wan2.2-Lightning_I2V-A14B-4steps-lora/resolve/main/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors
fi

# Скачиваем LoRA LOW
echo "=== Downloading LoRA LOW ==="
if [ ! -f "models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" ]; then
    wget -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors \
        https://huggingface.co/Kijai/Wan2.2-Lightning_I2V-A14B-4steps-lora/resolve/main/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors
fi

# Скачиваем RIFE модель
echo "=== Downloading RIFE model ==="
if [ ! -f "models/rife/rife47.pth" ]; then
    wget -O models/rife/rife47.pth \
        https://github.com/megvii-research/ECCV2022-RIFE/raw/main/train_log/rife47.pth
fi

echo "=== All models downloaded ==="

# Устанавливаем кастомные ноды
echo "=== Installing custom nodes ==="
cd custom_nodes

# WanVideo Wrapper
if [ ! -d "ComfyUI-WanVideoWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
    cd ComfyUI-WanVideoWrapper
    pip install -r requirements.txt
    cd ..
fi

# KJNodes
if [ ! -d "ComfyUI-KJNodes" ]; then
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
    cd ComfyUI-KJNodes
    pip install -r requirements.txt
    cd ..
fi

# Custom Scripts
if [ ! -d "cg-use-everywhere" ]; then
    git clone https://github.com/chrisgoringe/cg-use-everywhere.git
fi

# Frame Interpolation
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
    cd ComfyUI-Frame-Interpolation
    pip install -r requirements.txt
    cd ..
fi

# Easy Use
if [ ! -d "AIGODLIKE-ComfyUI-Translation" ]; then
    git clone https://github.com/AIGODLIKE/AIGODLIKE-ComfyUI-Translation.git
fi

echo "=== Provisioning complete ==="
