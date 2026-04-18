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

# WanVideo Wrapper
if [ ! -d "ComfyUI-WanVideoWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
fi

# KJNodes
if [ ! -d "ComfyUI-KJNodes" ]; then
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
fi

# Custom Scripts (MathExpression)
if [ ! -d "ComfyUI-Custom-Scripts" ]; then
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
fi

# Frame Interpolation (RIFE)
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
fi

# Easy Use
if [ ! -d "ComfyUI-Easy-Use" ]; then
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git
fi

echo "=== Custom nodes installed ==="

# Устанавливаем зависимости в ВИРТУАЛЬНОЕ ОКРУЖЕНИЕ ComfyUI
echo "=== Installing dependencies in venv ==="
/venv/main/bin/pip install --upgrade pip
/venv/main/bin/pip install --force-reinstall \
    torch \
    torchvision \
    torchaudio \
    accelerate \
    transformers \
    diffusers \
    peft \
    opencv-python \
    opencv-python-headless \
    GitPython \
    sentencepiece \
    protobuf \
    einops \
    ftfy
    gguf          # <--- добавил

# Проверяем
/venv/main/bin/python -c "import cv2; print('✅ OpenCV OK')"
/venv/main/bin/python -c "import accelerate; print('✅ Accelerate OK')"
/venv/main/bin/python -c "import gguf; print('✅ GGUF OK')"

# Создаём конфиг для Manager
mkdir -p custom_nodes/ComfyUI-Manager
echo -e '[default]\nsecurity_level = weak' > custom_nodes/ComfyUI-Manager/config.ini

# Удаляем флаг provisioning
rm -f /.provisioning 2>/dev/null || true

# Перезапускаем ComfyUI
echo "=== Restarting ComfyUI ==="
supervisorctl restart comfyui

echo "=== Provisioning complete ==="
