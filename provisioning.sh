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
wget -q --show-progress -O models/vae/wan_2.1_vae.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=1" || echo "VAE already exists"

# 2. Text Encoder
echo "=== Downloading Text Encoder ==="
wget -q --show-progress -O models/text_encoders/nsfw_wan_umt5-xxl_fp8_scaled.safetensors \
    "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors?download=1" || echo "Text Encoder already exists"

# 3. Diffusion model HIGH lighting
echo "=== Downloading Wan model HIGH lighting ==="
wget -q --show-progress -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors \
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors?download=1" || echo "HIGH model already exists"

# 4. Diffusion model LOW lighting
echo "=== Downloading Wan model LOW lighting ==="
wget -q --show-progress -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors \
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors?download=1" || echo "LOW model already exists"

# 5. LoRA HIGH
echo "=== Downloading LoRA HIGH ==="
wget -q --show-progress -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors?download=1" || echo "LoRA HIGH already exists"

# 6. LoRA LOW
echo "=== Downloading LoRA LOW ==="
wget -q --show-progress -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors?download=1" || echo "LoRA LOW already exists"

# 7. RIFE model
echo "=== Downloading RIFE model ==="
wget -q --show-progress -O models/rife/rife47.pth \
    "https://huggingface.co/jasonot/mycomfyui/resolve/main/rife47.pth?download=1" || echo "RIFE already exists"

echo "=== All models downloaded ==="

# Устанавливаем кастомные ноды
echo "=== Installing custom nodes ==="
cd /workspace/ComfyUI/custom_nodes

for repo in \
    "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" \
    "https://github.com/kijai/ComfyUI-KJNodes.git" \
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" \
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git" \
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
do
    dir=$(basename "$repo" .git)
    if [ ! -d "$dir" ]; then
        echo "--- Cloning $dir ---"
        git clone "$repo"
    else
        echo "--- $dir already exists, pulling latest ---"
        cd "$dir"
        git pull || true
        cd /workspace/ComfyUI/custom_nodes
    fi
done

echo "=== Installing dependencies for each custom node ==="

# Устанавливаем зависимости для каждой ноды
for dir in \
    "ComfyUI-WanVideoWrapper" \
    "ComfyUI-KJNodes" \
    "ComfyUI-Custom-Scripts" \
    "ComfyUI-Frame-Interpolation" \
    "ComfyUI-Easy-Use"
do
    if [ -f "/workspace/ComfyUI/custom_nodes/$dir/requirements.txt" ]; then
        echo "--- Installing requirements for $dir ---"
        /venv/main/bin/pip install --quiet -r "/workspace/ComfyUI/custom_nodes/$dir/requirements.txt" || echo "⚠️ Some requirements failed for $dir"
    else
        echo "--- No requirements.txt for $dir ---"
    fi
done

echo "=== Custom nodes installed ==="

# Устанавливаем общие зависимости
echo "=== Installing common dependencies ==="
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
    imageio \
    imageio-ffmpeg \
    av \
    kornia \
    || echo "⚠️ Some common dependencies failed"

echo "=== Dependencies installed ==="

# Создаём worker.py на порту 8289
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json, base64, time, os, requests, glob
from flask import Flask, request, jsonify
import traceback
import sys

app = Flask(__name__)

def log(msg):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    log_msg = f"[{timestamp}] [Worker] {msg}"
    print(log_msg, flush=True)
    sys.stderr.write(log_msg + "\n")
    sys.stderr.flush()

@app.route('/generate/sync', methods=['POST'])
def generate():
    try:
        log("=== NEW REQUEST ===")
        data = request.json
        workflow = data.get('workflow_json', {})
        img_b64 = data.get('image_base64', '')
        
        if not workflow or not img_b64:
            log("❌ Missing workflow or image")
            return jsonify({'error': 'Missing workflow or image'}), 400
        
        log(f"✅ Received workflow ({len(workflow)} nodes)")
        
        os.makedirs('/workspace/ComfyUI/input', exist_ok=True)
        img_path = '/workspace/ComfyUI/input/temp.jpg'
        with open(img_path, 'wb') as f:
            f.write(base64.b64decode(img_b64))
        
        workflow['148']['inputs']['image'] = 'temp.jpg'

        # Удаляем ноду WanVideoTorchCompileSettings если она есть
        # чтобы не было ошибки missing_node_type
        nodes_to_remove = []
        for node_id, node_data in workflow.items():
            if isinstance(node_data, dict):
                class_type = node_data.get('class_type', '')
                if class_type == 'WanVideoTorchCompileSettings':
                    nodes_to_remove.append(node_id)
                    log(f"⚠️ Removing unsupported node: {node_id} ({class_type})")
        
        for node_id in nodes_to_remove:
            del workflow[node_id]
        
        log("⏳ Waiting for ComfyUI...")
        for i in range(30):
            try:
                requests.get('http://localhost:18188/', timeout=2)
                log("✅ ComfyUI is ready")
                break
            except:
                time.sleep(1)
        
        log("📤 Sending workflow to ComfyUI...")
        resp = requests.post('http://localhost:18188/prompt', json={'prompt': workflow})
        if resp.status_code != 200:
            log(f"❌ ComfyUI error: {resp.text}")
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()['prompt_id']
        log(f"✅ Prompt ID: {prompt_id}")
        
        timeout = 1200
        start = time.time()
        check_count = 0
        
        log(f"⏳ Waiting for video (timeout: {timeout}s)...")
        
        while time.time() - start < timeout:
            check_count += 1
            elapsed = int(time.time() - start)
            
            try:
                resp = requests.get(f'http://localhost:18188/history/{prompt_id}')
                history = resp.json()
                
                if history.get(prompt_id):
                    outputs = history[prompt_id]['outputs']
                    
                    for node_id, node_output in outputs.items():
                        for key in ['videos', 'images']:
                            if key in node_output:
                                items = node_output[key]
                                if isinstance(items, list) and items:
                                    for item in items:
                                        if isinstance(item, dict) and 'filename' in item:
                                            filename = item['filename']
                                            subfolder = item.get('subfolder', '')
                                            
                                            if subfolder:
                                                video_path = f'/workspace/ComfyUI/output/{subfolder}/{filename}'
                                            else:
                                                video_path = f'/workspace/ComfyUI/output/{filename}'
                                            
                                            log(f"🎬 Found video in node {node_id}, key '{key}':")
                                            log(f"   Filename: {filename}")
                                            log(f"   Subfolder: {subfolder}")
                                            log(f"   Full path: {video_path}")
                                            
                                            if os.path.exists(video_path):
                                                file_size = os.path.getsize(video_path)
                                                log(f"   ✅ FILE EXISTS: {file_size} bytes ({file_size/1024:.1f}KB)")
                                                
                                                if file_size > 100000:
                                                    log(f"   ✅ FILE IS READY!")
                                                    
                                                    log(f"   📖 Reading file...")
                                                    with open(video_path, 'rb') as f:
                                                        video_bytes = f.read()
                                                    
                                                    log(f"   📊 File read: {len(video_bytes)} bytes")
                                                    
                                                    log(f"   🔐 Encoding to base64...")
                                                    video_b64 = base64.b64encode(video_bytes).decode()
                                                    
                                                    result = {
                                                        'success': True,
                                                        'video_filename': filename,
                                                        'video_base64': video_b64,
                                                        'file_size': len(video_bytes),
                                                        'elapsed': int(time.time() - start)
                                                    }
                                                    
                                                    log(f"✅ SUCCESS! Video ready: {len(video_bytes)} bytes in {int(time.time()-start)}s")
                                                    return jsonify(result), 200
                                                else:
                                                    log(f"   ⏳ File too small ({file_size} bytes), waiting...")
                                            else:
                                                log(f"   ⏳ FILE NOT EXISTS YET, waiting...")
                    
                    if check_count % 50 == 0:
                        log(f"  Check #{check_count} ({elapsed}s): waiting for video...")
                else:
                    if check_count % 50 == 0:
                        log(f"  Check #{check_count} ({elapsed}s): no outputs yet...")
                        
            except Exception as e:
                log(f"  Error: {e}")
                traceback.print_exc()
            
            time.sleep(2)
        
        log(f"❌ TIMEOUT after {timeout}s")
        return jsonify({'error': 'Timeout waiting for video'}), 500
        
    except Exception as e:
        log(f"❌ ERROR: {e}")
        log(traceback.format_exc())
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    log("🚀 Starting worker on port 8289...")
    app.run(host='0.0.0.0', port=8289, debug=False, threaded=True)
EOF

echo "=== worker.py created ==="

# Удаляем флаг
rm -f /.provisioning

# Ждём ComfyUI
echo "Waiting for ComfyUI to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:18188/ > /dev/null 2>&1; then
        echo "✅ ComfyUI is ready!"
        break
    fi
    echo "  Attempt $i/60..."
    sleep 3
done

# Запускаем worker на порту 8289
echo "=== Starting worker ==="
cd /workspace/ComfyUI
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &
WORKER_PID=$!
echo "Worker PID: $WORKER_PID"

sleep 5

# Проверяем worker
if curl -s http://localhost:8289/health > /dev/null 2>&1; then
    echo "✅ Worker started on port 8289"
else
    echo "⚠️ Worker health check failed, checking logs..."
    tail -20 /workspace/worker.log || true
fi

echo "=== Provisioning complete ==="
