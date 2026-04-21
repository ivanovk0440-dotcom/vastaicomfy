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

# VideoHelperSuite (нужен для CreateVideo)
if [ ! -d "ComfyUI-VideoHelperSuite" ]; then
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
    cd ComfyUI-VideoHelperSuite
    /venv/main/bin/pip install -r requirements.txt 2>/dev/null || true
    cd ..
fi

echo "=== Custom nodes installed ==="

# ============================================
# PyTorch для CUDA 12.6+
# ============================================
echo "=== Installing PyTorch for CUDA 12.6+ ==="
/venv/main/bin/pip uninstall torch torchvision torchaudio -y
/venv/main/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

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
/venv/main/bin/python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
/venv/main/bin/python -c "import cv2; print('✅ OpenCV OK')"
/venv/main/bin/python -c "import accelerate; print('✅ Accelerate OK')"
/venv/main/bin/python -c "import gguf; print('✅ GGUF OK')"

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
    "ComfyUI-Easy-Use",
    "ComfyUI-VideoHelperSuite"
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

# Создаём папку для видео
mkdir -p /workspace/ComfyUI/output/video

# ПРИНУДИТЕЛЬНО СОЗДАЁМ ПАПКУ input (ГАРАНТИРУЕМ, ЧТО ЭТО НЕ ФАЙЛ)
rm -rf /workspace/ComfyUI/input
mkdir -p /workspace/ComfyUI/input

# Создаём worker.py (ИСПРАВЛЕННАЯ ВЕРСИЯ v3)
echo "=== Creating worker.py ==="
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json
import base64
import time
import os
import requests
import glob
from flask import Flask, request, jsonify
from PIL import Image
import io

app = Flask(__name__)

COMFYUI_PORT = 18188
COMFYUI_URL = f"http://localhost:{COMFYUI_PORT}"
COMFYUI_BASE = "/workspace/ComfyUI"

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
        
        print("\n" + "="*60)
        print("🎬 PROCESSING REQUEST")
        print("="*60)
        
        # Сохраняем картинку в input папку
        input_dir = os.path.join(COMFYUI_BASE, 'input')
        print(f"📁 Input directory: {input_dir}")
        
        # Убеждаемся что input это ПАПКА, не файл
        if os.path.exists(input_dir) and not os.path.isdir(input_dir):
            print(f"⚠️  {input_dir} is a file, removing...")
            os.remove(input_dir)
        
        os.makedirs(input_dir, exist_ok=True)
        print(f"✅ Input directory ready")
        
        # Декодируем base64 и сохраняем через PIL
        try:
            img_data = base64.b64decode(img_b64)
            img = Image.open(io.BytesIO(img_data))
            
            img_path = os.path.join(input_dir, 'temp.jpg')
            img.save(img_path, 'JPEG', quality=95)
            
            file_size = os.path.getsize(img_path)
            print(f"✅ Image saved: {img_path}")
            print(f"   Size: {file_size} bytes")
            print(f"   Format: {img.format}, Dimensions: {img.size}")
        except Exception as e:
            print(f"❌ Failed to save image: {e}")
            return jsonify({'error': f'Image save failed: {str(e)}'}), 400
        
        # Проверяем что файл существует
        if not os.path.exists(img_path):
            print(f"❌ Image file not found after save: {img_path}")
            return jsonify({'error': 'Image file not found'}), 500
        
        print(f"✅ Image file verified: {os.path.getsize(img_path)} bytes")
        
        # Список файлов в input папке
        files_in_input = os.listdir(input_dir)
        print(f"   Files in input directory: {files_in_input}")
        
        # Обновляем ноду LoadImage (148)
        if "148" in workflow:
            if "inputs" not in workflow["148"]:
                workflow["148"]["inputs"] = {}
            
            workflow["148"]["inputs"]["image"] = "temp.jpg"
            print(f"✅ Updated node 148")
            print(f"   image = 'temp.jpg'")
            
            # Убираем upload/absolute path если они есть
            if "upload" in workflow["148"]["inputs"]:
                del workflow["148"]["inputs"]["upload"]
        else:
            print(f"⚠️  Node 148 not found in workflow, searching for LoadImage...")
            for node_id, node in workflow.items():
                if node.get("class_type") == "LoadImage":
                    if "inputs" not in node:
                        node["inputs"] = {}
                    node["inputs"]["image"] = "temp.jpg"
                    print(f"✅ Found LoadImage in node {node_id}")
                    break
        
        # Ждём ComfyUI
        print(f"\n🔍 Waiting for ComfyUI...")
        for i in range(60):
            try:
                resp = requests.get(f'{COMFYUI_URL}/', timeout=2)
                if resp.status_code == 200:
                    print(f"✅ ComfyUI ready (attempt {i+1})")
                    break
            except:
                pass
            if i % 10 == 0:
                print(f"   Attempt {i+1}/60...")
            time.sleep(1)
        
        # Отправляем запрос
        print(f"\n📤 Sending prompt to ComfyUI...")
        resp = requests.post(f'{COMFYUI_URL}/prompt', json={'prompt': workflow})
        print(f"   Status: {resp.status_code}")
        
        if resp.status_code != 200:
            error_text = resp.text[:500]
            print(f"❌ ComfyUI error: {error_text}")
            return jsonify({'error': f'ComfyUI error: {error_text}'}), 500
        
        resp_data = resp.json()
        if 'prompt_id' not in resp_data:
            print(f"❌ No prompt_id in response: {resp_data}")
            return jsonify({'error': 'No prompt_id received'}), 500
        
        prompt_id = resp_data['prompt_id']
        print(f"✅ Prompt ID: {prompt_id}")
        
        # Ждём результат
        print(f"\n⏳ Waiting for generation (timeout: 600s)...")
        timeout = 600
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                resp = requests.get(f'{COMFYUI_URL}/history/{prompt_id}')
                data = resp.json()
                
                if data.get(prompt_id):
                    print(f"✅ Result found!")
                    outputs = data[prompt_id]['outputs']
                    
                    # Ищем видео или изображение в outputs
                    for node_id, node_output in outputs.items():
                        if 'videos' in node_output and node_output['videos']:
                            video_filename = node_output['videos'][0]['filename']
                            subfolder = node_output['videos'][0].get('subfolder', '')
                            url = f'{COMFYUI_URL}/view?filename={video_filename}'
                            if subfolder:
                                url += f'&subfolder={subfolder}'
                            print(f"✅ Video found: {video_filename}")
                            return jsonify({'video_url': url})
                        
                        if 'video' in node_output and node_output['video']:
                            video_filename = node_output['video'][0]['filename']
                            subfolder = node_output['video'][0].get('subfolder', '')
                            url = f'{COMFYUI_URL}/view?filename={video_filename}'
                            if subfolder:
                                url += f'&subfolder={subfolder}'
                            print(f"✅ Video found: {video_filename}")
                            return jsonify({'video_url': url})
                        
                        if 'images' in node_output and node_output['images']:
                            image_filename = node_output['images'][0]['filename']
                            subfolder = node_output['images'][0].get('subfolder', '')
                            url = f'{COMFYUI_URL}/view?filename={image_filename}'
                            if subfolder:
                                url += f'&subfolder={subfolder}'
                            print(f"✅ Image found: {image_filename}")
                            return jsonify({'video_url': url})
                    
                    print("⚠️  No output files found in history")
                    return jsonify({'error': 'No output found'}), 500
            except Exception as e:
                print(f"   Error checking history: {e}")
            
            elapsed = int(time.time() - start_time)
            if elapsed % 10 == 0:
                print(f"   Elapsed: {elapsed}s...")
            time.sleep(2)
        
        print(f"❌ Timeout after {timeout}s")
        return jsonify({'error': f'Timeout waiting for generation'}), 500
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print(f"Starting worker on port 8288")
    print(f"ComfyUI at: {COMFYUI_URL}")
    app.run(host='0.0.0.0', port=8288, debug=False)
EOF

# Удаляем флаг provisioning
rm -f /.provisioning 2>/dev/null || true

# Перезапускаем ComfyUI
echo "=== Restarting ComfyUI ==="
supervisorctl restart comfyui

# Ждём запуска ComfyUI
echo "Waiting for ComfyUI to start..."
for i in {1..30}; do
    if curl -s http://localhost:18188/ > /dev/null 2>&1; then
        echo "✅ ComfyUI is running on port 18188!"
        break
    fi
    sleep 2
done

# Запускаем worker
cd /workspace/ComfyUI
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

sleep 5

echo "=== Provisioning complete ==="
