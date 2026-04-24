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
cd custom_nodes

for repo in \
    "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" \
    "https://github.com/kijai/ComfyUI-KJNodes.git" \
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" \
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git" \
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
do
    dir=$(basename "$repo" .git)
    if [ ! -d "$dir" ]; then
        git clone "$repo"
    fi
done

echo "=== Custom nodes installed ==="

# Устанавливаем зависимости
echo "=== Installing dependencies ==="
/venv/main/bin/pip install --quiet --upgrade pip
/venv/main/bin/pip install --quiet \
    flask requests \
    opencv-python opencv-python-headless \
    accelerate transformers diffusers peft \
    gguf ftfy einops sentencepiece protobuf

echo "=== Dependencies installed ==="

# Создаём worker.py на порту 8289
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json, base64, time, os, requests, glob
from flask import Flask, request, jsonify
import traceback
import sys

app = Flask(__name__)

# Логируем в stderr и stdout одновременно
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
        
        log(f"✅ Received workflow ({len(workflow)} nodes) and image ({len(img_b64)} chars)")
        
        os.makedirs('/workspace/ComfyUI/input', exist_ok=True)
        img_path = '/workspace/ComfyUI/input/temp.jpg'
        with open(img_path, 'wb') as f:
            f.write(base64.b64decode(img_b64))
        log(f"✅ Image saved: {img_path}")
        
        workflow['148']['inputs']['image'] = 'temp.jpg'
        
        # Ждём ComfyUI
        log("⏳ Waiting for ComfyUI...")
        for i in range(30):
            try:
                requests.get('http://localhost:18188/', timeout=2)
                log("✅ ComfyUI is ready")
                break
            except:
                time.sleep(1)
        
        # Отправляем workflow
        log("📤 Sending workflow to ComfyUI...")
        resp = requests.post('http://localhost:18188/prompt', json={'prompt': workflow})
        if resp.status_code != 200:
            log(f"❌ ComfyUI error: {resp.text}")
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()['prompt_id']
        log(f"✅ Prompt ID: {prompt_id}")
        
        # Ждём видео (20 минут)
        timeout = 1200
        start = time.time()
        check_count = 0
        video_found = False
        video_filename = None
        video_path = None
        
        log(f"⏳ Waiting for video (timeout: {timeout}s)...")
        
        while time.time() - start < timeout:
            check_count += 1
            elapsed = int(time.time() - start)
            
            try:
                resp = requests.get(f'http://localhost:18188/history/{prompt_id}')
                history = resp.json()
                
                if history.get(prompt_id):
                    outputs = history[prompt_id]['outputs']
                    
                    if check_count % 10 == 0:
                        log(f"  Check #{check_count} ({elapsed}s): outputs ready")
                    
                    # Ищем видео
                    for node_id, node_output in outputs.items():
                        if 'videos' in node_output and node_output['videos']:
                            video_filename = node_output['videos'][0]['filename']
                            video_path = f'/workspace/ComfyUI/output/{video_filename}'
                            video_found = True
                            log(f"✅ Video found in node {node_id}: {video_filename}")
                            break
                    
                    if video_found:
                        break
                else:
                    if check_count % 10 == 0:
                        log(f"  Check #{check_count} ({elapsed}s): waiting...")
                        
            except Exception as e:
                log(f"  Error checking history: {e}")
            
            time.sleep(2)
        
        if not video_found:
            log("❌ Video not found in history, searching disk...")
            
            # Fallback - ищем на диске
            for attempt in range(60):
                videos = glob.glob('/workspace/ComfyUI/output/**/*.mp4', recursive=True)
                if videos:
                    video_path = max(videos, key=os.path.getctime)
                    video_filename = os.path.basename(video_path)
                    log(f"✅ Found on disk: {video_filename}")
                    video_found = True
                    break
                
                if attempt % 10 == 0:
                    log(f"  Disk search attempt {attempt+1}/60...")
                time.sleep(1)
        
        if not video_found:
            log(f"❌ Video file not found after {timeout}s + disk search")
            return jsonify({'error': 'Video not found'}), 500
        
        # Ждём файл на диске
        log(f"⏳ Waiting for video file: {video_path}...")
        for wait_attempt in range(120):
            if os.path.exists(video_path):
                file_size = os.path.getsize(video_path)
                
                if file_size > 1000000:  # > 1MB
                    log(f"✅ Video file ready: {file_size} bytes")
                    break
            
            if wait_attempt % 10 == 0:
                log(f"  File wait attempt {wait_attempt+1}/120...")
            time.sleep(1)
        
        # Читаем и кодируем видео
        log(f"📖 Reading video file...")
        try:
            with open(video_path, 'rb') as f:
                video_bytes = f.read()
        except Exception as e:
            log(f"❌ Failed to read video: {e}")
            return jsonify({'error': f'Failed to read video: {e}'}), 500
        
        if not video_bytes:
            log(f"❌ Video file is empty")
            return jsonify({'error': 'Video file is empty'}), 500
        
        log(f"✅ Video read: {len(video_bytes)} bytes")
        
        # Кодируем в base64
        log(f"🔐 Encoding to base64...")
        video_b64 = base64.b64encode(video_bytes).decode()
        log(f"✅ Encoded: {len(video_b64)} chars")
        
        # Возвращаем результат
        result = {
            'success': True,
            'video_filename': video_filename,
            'video_base64': video_b64,
            'file_size': len(video_bytes),
            'elapsed': int(time.time() - start)
        }
        
        log(f"✅ COMPLETE! Returning video ({len(video_bytes)} bytes, {int(time.time()-start)}s)")
        return jsonify(result), 200
        
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

echo "=== Provisioning script finished ==="

# Удаляем флаг
rm -f /.provisioning

# Ждём ComfyUI
echo "Waiting for ComfyUI to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:18188/ > /dev/null 2>&1; then
        echo "ComfyUI is ready!"
        break
    fi
    sleep 2
done

# Запускаем worker на порту 8289
cd /workspace/ComfyUI
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

sleep 5

# Проверяем worker
if curl -s http://localhost:8289/ > /dev/null 2>&1; then
    echo "✅ Worker started on port 8289"
else
    echo "⚠️ Worker may not be ready yet"
fi

echo "=== Provisioning complete ==="
