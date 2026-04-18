#!/bin/bash
set -e

echo "=== Starting provisioning ==="
cd /workspace/ComfyUI

# Создаём папки для моделей
mkdir -p models/diffusion_models
mkdir -p models/text_encoders
mkdir -p models/vae
mkdir -p models/loras
mkdir -p models/rife

# 1. VAE
echo "=== Downloading VAE ==="
if [ ! -f "models/vae/wan_2.1_vae.safetensors" ]; then
    wget -O models/vae/wan_2.1_vae.safetensors \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=1"
fi

# 2. Text Encoder
echo "=== Downloading Text Encoder ==="
if [ ! -f "models/text_encoders/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" ]; then
    wget -O models/text_encoders/nsfw_wan_umt5-xxl_fp8_scaled.safetensors \
        "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors?download=1"
fi

# 3. Diffusion model HIGH lighting
echo "=== Downloading Wan model HIGH lighting ==="
if [ ! -f "models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" ]; then
    wget -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors \
        "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors?download=1"
fi

# 4. Diffusion model LOW lighting
echo "=== Downloading Wan model LOW lighting ==="
if [ ! -f "models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" ]; then
    wget -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors \
        "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors?download=1"
fi

# 5. LoRA HIGH
echo "=== Downloading LoRA HIGH ==="
if [ ! -f "models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors" ]; then
    wget -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors?download=1"
fi

# 6. LoRA LOW
echo "=== Downloading LoRA LOW ==="
if [ ! -f "models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors" ]; then
    wget -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors?download=1"
fi

# 7. RIFE model
echo "=== Downloading RIFE model ==="
if [ ! -f "models/rife/rife47.pth" ]; then
    wget -O models/rife/rife47.pth \
        "https://huggingface.co/jasonot/mycomfyui/resolve/main/rife47.pth?download=1"
fi

echo "=== All models downloaded ==="

# Устанавливаем кастомные ноды
echo "=== Installing custom nodes ==="
cd custom_nodes

# WanVideo Wrapper (kijai)
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

# Custom Scripts (MathExpression) - правильный репозиторий для воркфлоу
if [ ! -d "ComfyUI-Custom-Scripts" ]; then
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
    cd ComfyUI-Custom-Scripts
    cd ..
fi

# Frame Interpolation (RIFE)
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
    cd ComfyUI-Frame-Interpolation
    pip install -r requirements.txt
    cd ..
fi

# Easy Use (правильный репозиторий)
if [ ! -d "ComfyUI-Easy-Use" ]; then
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git
    cd ComfyUI-Easy-Use
    pip install -r requirements.txt
    cd ..
fi

echo "=== Custom nodes installed ==="

# Устанавливаем критически важную зависимость opencv-python (нужна для Easy-Use и WanVideoWrapper)
echo "=== Installing missing system dependencies ==="
pip install opencv-python opencv-python-headless

# Запускаем Try Fix через ComfyUI-Manager CLI
echo "=== Running ComfyUI-Manager fix ==="
cd /workspace/ComfyUI

# Создаём config.ini если нет
mkdir -p custom_nodes/ComfyUI-Manager
if [ ! -f "custom_nodes/ComfyUI-Manager/config.ini" ]; then
    echo -e '[default]\nsecurity_level = weak' > custom_nodes/ComfyUI-Manager/config.ini
fi

echo "=== Running ComfyUI-Manager fix for each node ==="
cd /workspace/ComfyUI

# Создаём config.ini если нет
mkdir -p custom_nodes/ComfyUI-Manager
if [ ! -f "custom_nodes/ComfyUI-Manager/config.ini" ]; then
    echo -e '[default]\nsecurity_level = weak' > custom_nodes/ComfyUI-Manager/config.ini
fi

# Фиксим по очереди (по одному, чтобы избежать ошибок)
python custom_nodes/ComfyUI-Manager/cm-cli.py fix ComfyUI-WanVideoWrapper
sleep 2
python custom_nodes/ComfyUI-Manager/cm-cli.py fix ComfyUI-Easy-Use
sleep 2
python custom_nodes/ComfyUI-Manager/cm-cli.py fix ComfyUI-Custom-Scripts
sleep 2
python custom_nodes/ComfyUI-Manager/cm-cli.py fix ComfyUI-KJNodes
sleep 2
python custom_nodes/ComfyUI-Manager/cm-cli.py fix ComfyUI-Frame-Interpolation

echo "=== Fix completed ==="

# Перезапускаем ComfyUI через supervisor
echo "=== Restarting ComfyUI ==="
supervisorctl restart comfyui

echo "=== Provisioning complete ==="
