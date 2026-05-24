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
mkdir -p models/controlnet
mkdir -p input
mkdir -p output

# 1. VAE
echo "=== Downloading VAE ==="
if [ ! -f models/vae/wan_2.1_vae.safetensors ]; then
    wget -q --show-progress -O models/vae/wan_2.1_vae.safetensors \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
else
    echo "VAE already exists"
fi

# 2. Text Encoder
echo "=== Downloading Text Encoder ==="
if [ ! -f models/text_encoders/nsfw_wan_umt5-xxl_fp8_scaled.safetensors ]; then
    wget -q --show-progress -O models/text_encoders/nsfw_wan_umt5-xxl_fp8_scaled.safetensors \
        "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
else
    echo "Text Encoder already exists"
fi

# 3. Diffusion model HIGH lighting
echo "=== Downloading Wan model HIGH lighting ==="
if [ ! -f models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors ]; then
    wget -q --show-progress -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors \
        "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
else
    echo "HIGH model already exists"
fi

# 4. Diffusion model LOW lighting
echo "=== Downloading Wan model LOW lighting ==="
if [ ! -f models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors ]; then
    wget -q --show-progress -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors \
        "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
else
    echo "LOW model already exists"
fi

# 5. RIFE model
echo "=== Downloading RIFE model ==="
if [ ! -f models/rife/rife47.pth ]; then
    wget -q --show-progress -O models/rife/rife47.pth \
        "https://huggingface.co/jasonot/mycomfyui/resolve/main/rife47.pth"
else
    echo "RIFE already exists"
fi

echo "=== All models downloaded ==="

# Устанавливаем кастомные ноды
echo "=== Installing custom nodes ==="
cd custom_nodes

# ComfyUI-WanVideoWrapper (СВЕЖАЯ ВЕРСИЯ - с TorchCompileSettings и BlockSwap)
echo "Installing ComfyUI-WanVideoWrapper..."
rm -rf ComfyUI-WanVideoWrapper
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
cd ComfyUI-WanVideoWrapper
git pull origin main
/venv/main/bin/pip install -r requirements.txt
cd ..

# Остальные ноды
for repo in \
    "https://github.com/kijai/ComfyUI-KJNodes.git" \
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" \
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git" \
    "https://github.com/yolain/ComfyUI-Easy-Use.git" \
    "https://github.com/rgthree/rgthree-comfy.git" \
    "https://github.com/chrisgoringe/cg-use-everywhere.git"
do
    dir=$(basename "$repo" .git)
    if [ ! -d "$dir" ]; then
        echo "Installing $dir..."
        git clone "$repo"
        if [ -f "$dir/requirements.txt" ]; then
            /venv/main/bin/pip install -r "$dir/requirements.txt" 2>/dev/null || true
        fi
    fi
done

cd ..

echo "=== Custom nodes installed ==="

# Устанавливаем зависимости
echo "=== Installing dependencies ==="
/venv/main/bin/pip install --quiet --upgrade pip
/venv/main/bin/pip install --quiet \
    flask \
    requests \
    opencv-python \
    opencv-python-headless \
    accelerate \
    transformers \
    diffusers \
    peft \
    gguf \
    ftfy \
    einops \
    sentencepiece \
    protobuf \
    watchdog \
    filelock

# Устанавливаем PyTorch с CUDA поддержкой
/venv/main/bin/pip install --quiet torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

echo "=== Dependencies installed ==="

# Создаём worker.py
echo "=== Creating worker.py ==="
cat > /workspace/ComfyUI/worker.py << 'WORKER_EOF'
import json
import base64
import time
import os
import requests
import traceback
import sys
import glob
from flask import Flask, request, jsonify
from threading import Lock

app = Flask(__name__)
request_lock = Lock()

def log(msg):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_msg = f"[{timestamp}] [Worker] {msg}"
    print(log_msg, flush=True)
    sys.stderr.write(log_msg + "\n")
    sys.stderr.flush()

def fix_workflow(workflow):
    """Исправляет workflow - удаляет проблемные ноды и ссылки"""
    workflow = workflow.copy()
    
    # Список нод, которые могут отсутствовать
    nodes_to_remove = []
    
    # Проверяем каждую ноду
    for node_id, node in workflow.items():
        class_type = node.get('class_type', '')
        
        # Если класс ноды疑似 отсутствует, удаляем ноду
        if class_type in ['WanVideoTorchCompileSettings', 'WanVideoBlockSwap']:
            nodes_to_remove.append(node_id)
            log(f"Will remove node {node_id} ({class_type})")
    
    # Удаляем проблемные ноды
    for node_id in nodes_to_remove:
        if node_id in workflow:
            del workflow[node_id]
    
    # Удаляем ссылки на удалённые ноды
    for node_id, node in workflow.items():
        if 'inputs' in node:
            inputs = node['inputs']
            for key, value in list(inputs.items()):
                if isinstance(value, list) and len(value) == 2:
                    if value[0] in nodes_to_remove:
                        if key in ['compile_args', 'block_swap_args']:
                            del inputs[key]
                            log(f"Removed {key} from node {node_id}")
    
    return workflow

@app.route('/generate/sync', methods=['POST'])
def generate():
    with request_lock:
        try:
            log("=== NEW REQUEST ===")
            data = request.json
            workflow = data.get('workflow_json', {})
            img_b64 = data.get('image_base64', '')
            
            if not workflow or not img_b64:
                log("❌ Missing workflow or image")
                return jsonify({'error': 'Missing workflow or image'}), 400
            
            log(f"✅ Received workflow with {len(workflow)} nodes")
            
            # Исправляем workflow
            workflow = fix_workflow(workflow)
            log(f"✅ After fix: {len(workflow)} nodes")
            
            # Сохраняем изображение
            os.makedirs('/workspace/ComfyUI/input', exist_ok=True)
            img_path = '/workspace/ComfyUI/input/temp.jpg'
            with open(img_path, 'wb') as f:
                f.write(base64.b64decode(img_b64))
            
            # Обновляем путь в ноде LoadImage
            for node_id, node in workflow.items():
                if node.get('class_type') == 'LoadImage':
                    node['inputs']['image'] = 'temp.jpg'
                    log(f"Updated LoadImage node {node_id}")
            
            log("⏳ Waiting for ComfyUI...")
            for i in range(30):
                try:
                    resp = requests.get('http://localhost:18188/', timeout=2)
                    if resp.status_code == 200:
                        log("✅ ComfyUI is ready")
                        break
                except:
                    pass
                time.sleep(1)
            
            log("📤 Sending workflow to ComfyUI...")
            resp = requests.post('http://localhost:18188/prompt', 
                                json={'prompt': workflow},
                                timeout=30)
            
            if resp.status_code != 200:
                log(f"❌ ComfyUI error: {resp.text}")
                return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
            
            prompt_id = resp.json()['prompt_id']
            log(f"✅ Prompt ID: {prompt_id}")
            
            timeout = 1200
            start = time.time()
            last_log = 0
            
            while time.time() - start < timeout:
                try:
                    resp = requests.get(f'http://localhost:18188/history/{prompt_id}', timeout=10)
                    history = resp.json()
                    
                    if history.get(prompt_id):
                        outputs = history[prompt_id]['outputs']
                        
                        # Ищем видео
                        for node_id, node_output in outputs.items():
                            for key in ['videos', 'images']:
                                if key in node_output:
                                    items = node_output[key]
                                    if isinstance(items, list) and items:
                                        for item in items:
                                            if isinstance(item, dict) and 'filename' in item:
                                                filename = item['filename']
                                                subfolder = item.get('subfolder', '')
                                                
                                                if filename.endswith(('.mp4', '.webm', '.avi', '.mov')):
                                                    if subfolder:
                                                        video_path = f'/workspace/ComfyUI/output/{subfolder}/{filename}'
                                                    else:
                                                        video_path = f'/workspace/ComfyUI/output/{filename}'
                                                    
                                                    if os.path.exists(video_path):
                                                        file_size = os.path.getsize(video_path)
                                                        if file_size > 100000:
                                                            log(f"✅ Found video: {video_path} ({file_size} bytes)")
                                                            
                                                            with open(video_path, 'rb') as f:
                                                                video_bytes = f.read()
                                                            
                                                            video_b64 = base64.b64encode(video_bytes).decode()
                                                            
                                                            return jsonify({
                                                                'success': True,
                                                                'video_filename': filename,
                                                                'video_base64': video_b64,
                                                                'file_size': len(video_bytes),
                                                                'elapsed': int(time.time() - start)
                                                            }), 200
                                                
                                                # Также проверяем jpg/mp4 в outputs
                                                if filename.endswith(('.jpg', '.png', '.jpeg')):
                                                    # Может быть превью, игнорируем
                                                    pass
                    
                    # Логируем каждые 30 секунд
                    if int(time.time() - start) - last_log >= 30:
                        last_log = int(time.time() - start)
                        log(f"⏳ Still waiting... {int(time.time() - start)}s elapsed")
                        
                except Exception as e:
                    log(f"Error checking history: {e}")
                
                time.sleep(2)
            
            log(f"❌ TIMEOUT after {timeout}s")
            return jsonify({'error': 'Timeout waiting for video'}), 500
            
        except Exception as e:
            log(f"❌ ERROR: {e}")
            log(traceback.format_exc())
            return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'ready': True}), 200

@app.route('/system_stats', methods=['GET'])
def system_stats():
    return jsonify({
        'status': 'ok',
        'gpu_memory': 'unknown',
        'queue_size': 0
    }), 200

if __name__ == '__main__':
    log("🚀 Starting worker on port 8289...")
    app.run(host='0.0.0.0', port=8289, debug=False, threaded=True)
WORKER_EOF

echo "=== Worker created ==="

# Останавливаем существующие процессы
echo "=== Stopping existing processes ==="
pkill -f "ComfyUI" || true
pkill -f "worker.py" || true
sleep 3

# Запускаем ComfyUI
echo "=== Starting ComfyUI ==="
cd /workspace/ComfyUI
nohup python main.py --listen 0.0.0.0 --port 18188 > /workspace/comfyui.log 2>&1 &

echo "Waiting for ComfyUI to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:18188/ > /dev/null 2>&1; then
        echo "✅ ComfyUI is ready!"
        break
    fi
    sleep 2
done

# Запускаем worker
echo "=== Starting worker ==="
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

sleep 5

# Проверяем worker
if curl -s http://localhost:8289/health > /dev/null 2>&1; then
    echo "✅ Worker started on port 8289"
else
    echo "⚠️ Worker may not be ready yet, check logs: /workspace/worker.log"
fi

echo "=== Provisioning complete ==="

# Удаляем флаг провижининга
rm -f /.provisioning

# Выводим информацию
echo ""
echo "=========================================="
echo "INSTANCE IS READY!"
echo "ComfyUI: http://localhost:18188"
echo "Worker: http://localhost:8289"
echo "=========================================="
