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
    cd ComfyUI-WanVideoWrapper
    /venv/main/bin/pip install -r requirements.txt 2>/dev/null || true
    cd ..
fi

# KJNodes
if [ ! -d "ComfyUI-KJNodes" ]; then
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
    cd ComfyUI-KJNodes
    /venv/main/bin/pip install -r requirements.txt 2>/dev/null || true
    cd ..
fi

# Custom Scripts (MathExpression)
if [ ! -d "ComfyUI-Custom-Scripts" ]; then
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
    cd ComfyUI-Custom-Scripts
    /venv/main/bin/pip install -r requirements.txt 2>/dev/null || true
    cd ..
fi

# Frame Interpolation (RIFE)
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
    cd ComfyUI-Frame-Interpolation
    /venv/main/bin/pip install -r requirements.txt 2>/dev/null || true
    cd ..
fi

# Easy Use
if [ ! -d "ComfyUI-Easy-Use" ]; then
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git
    cd ComfyUI-Easy-Use
    /venv/main/bin/pip install -r requirements.txt 2>/dev/null || true
    cd ..
fi

echo "=== Custom nodes installed ==="

# ============================================
# КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: Совместимый PyTorch для старых драйверов
# ============================================
echo "=== Installing PyTorch for old drivers (CUDA 11.8) ==="
/venv/main/bin/pip uninstall torch torchvision torchaudio -y
/venv/main/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Остальные зависимости
echo "=== Installing other dependencies ==="
/venv/main/bin/pip install --upgrade pip
/venv/main/bin/pip install \
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
    ftfy \
    gguf \
    numba \
    scipy \
    imageio \
    imageio-ffmpeg \
    numexpr

# Проверяем
/venv/main/bin/python -c "import torch; print(f'✅ PyTorch {torch.__version__} OK')"
/venv/main/bin/python -c "import cv2; print('✅ OpenCV OK')"
/venv/main/bin/python -c "import accelerate; print('✅ Accelerate OK')"
/venv/main/bin/python -c "import gguf; print('✅ GGUF OK')"

# Создаём worker.py для API-формата
echo "=== Creating worker.py for API format ==="
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json, base64, time, os, requests
from flask import Flask, request, jsonify

app = Flask(__name__)

# Определяем порт ComfyUI
COMFYUI_PORT = os.environ.get('COMFYUI_PORT', '8188')
COMFYUI_URL = f"http://127.0.0.1:{COMFYUI_PORT}"

@app.route('/generate/sync', methods=['POST'])
def generate():
    try:
        data = request.json
        if "input" in data:
            workflow = data["input"].get("workflow_json", {})
            img_b64 = data["input"].get("image_base64", "")
        else:
            workflow = data.get("workflow_json", {})
            img_b64 = data.get("image_base64", "")
        
        if not workflow or not img_b64:
            return jsonify({'error': 'Missing workflow or image'}), 400
        
        # Сохраняем картинку
        os.makedirs('/workspace/ComfyUI/input', exist_ok=True)
        img_path = '/workspace/ComfyUI/input/temp.jpg'
        with open(img_path, 'wb') as f:
            f.write(base64.b64decode(img_b64))
        
        # Обновляем ноду LoadImage (148) в API-формате
        if "148" in workflow:
            if "inputs" not in workflow["148"]:
                workflow["148"]["inputs"] = {}
            workflow["148"]["inputs"]["image"] = "temp.jpg"
        
        # Ждём ComfyUI
        for _ in range(30):
            try:
                requests.get(f'{COMFYUI_URL}/', timeout=2)
                break
            except:
                time.sleep(1)
        
        # Отправляем workflow в ComfyUI
        resp = requests.post(f'{COMFYUI_URL}/prompt', json={'prompt': workflow})
        if resp.status_code != 200:
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()['prompt_id']
        print(f"✅ Prompt ID: {prompt_id}")
        
        # Ждём результат
        timeout = 300
        start = time.time()
        while time.time() - start < timeout:
            try:
                resp = requests.get(f'{COMFYUI_URL}/history/{prompt_id}')
                data = resp.json()
                
                if data.get(prompt_id):
                    outputs = data[prompt_id]['outputs']
                    print(f"=== OUTPUTS ===")
                    for node_id, node_output in outputs.items():
                        print(f"Node {node_id}: {list(node_output.keys())}")
                        if 'videos' in node_output and node_output['videos']:
                            video_filename = node_output['videos'][0]['filename']
                            return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}'})
                        if 'video' in node_output and node_output['video']:
                            video_filename = node_output['video'][0]['filename']
                            return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}'})
                        if 'images' in node_output and node_output['images']:
                            print(f"  IMAGES in {node_id}: {len(node_output['images'])}")
                    print(f"=== END OUTPUTS ===")
                    return jsonify({'error': 'Video not found in outputs'}), 500
            except Exception as e:
                print(f"Error checking: {e}")
            time.sleep(2)
        
        return jsonify({'error': 'Timeout waiting for video'}), 500
        
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print(f"Starting worker on port 8288, ComfyUI at {COMFYUI_URL}")
    app.run(host='0.0.0.0', port=8288)
EOF

# Создаём конфиг для Manager
mkdir -p custom_nodes/ComfyUI-Manager
cat > custom_nodes/ComfyUI-Manager/config.ini << 'EOF'
[default]
security_level = weak
git_check = False
EOF

# Автоматический фикс нод
echo "=== Running auto-fix for nodes ==="
cat > /tmp/fix_nodes.py << 'EOF'
import os
import shutil

custom_nodes_path = "/workspace/ComfyUI/custom_nodes"
nodes_to_fix = [
    "ComfyUI-Custom-Scripts",
    "ComfyUI-WanVideoWrapper",
    "ComfyUI-KJNodes",
    "ComfyUI-Frame-Interpolation",
    "ComfyUI-Easy-Use"
]

for node in nodes_to_fix:
    node_path = os.path.join(custom_nodes_path, node)
    if os.path.exists(node_path):
        init_file = os.path.join(node_path, "__init__.py")
        if not os.path.exists(init_file):
            with open(init_file, "w") as f:
                f.write("# Auto-generated\n")
            print(f"✅ Created __init__.py for {node}")
        
        for root, dirs, files in os.walk(node_path):
            for file in files:
                if file.endswith(".pyc"):
                    os.remove(os.path.join(root, file))
            if "__pycache__" in dirs:
                shutil.rmtree(os.path.join(root, "__pycache__"), ignore_errors=True)
        print(f"✅ Fixed {node}")
print("✅ Auto-fix completed")
EOF

/venv/main/bin/python /tmp/fix_nodes.py

# Удаляем флаг provisioning
rm -f /.provisioning 2>/dev/null || true

# Перезапускаем ComfyUI
echo "=== Restarting ComfyUI ==="
supervisorctl restart comfyui

# Ждём запуска ComfyUI
echo "Waiting for ComfyUI to start..."
for i in {1..30}; do
    if curl -s http://localhost:8188/ > /dev/null 2>&1; then
        echo "✅ ComfyUI is running!"
        break
    fi
    sleep 2
done

# Запускаем worker
cd /workspace/ComfyUI
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

sleep 5

echo "=== Provisioning complete ==="
