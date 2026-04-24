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

app = Flask(__name__)

@app.route('/generate/sync', methods=['POST'])
def generate():
    try:
        data = request.json
        workflow = data.get('workflow_json', {})
        img_b64 = data.get('image_base64', '')
        
        if not workflow or not img_b64:
            return jsonify({'error': 'Missing workflow or image'}), 400
        
        os.makedirs('/workspace/ComfyUI/input', exist_ok=True)
        img_path = '/workspace/ComfyUI/input/temp.jpg'
        with open(img_path, 'wb') as f:
            f.write(base64.b64decode(img_b64))
        
        workflow['148']['inputs']['image'] = 'temp.jpg'
        
        for i in range(30):
            try:
                requests.get('http://localhost:18188/', timeout=2)
                break
            except:
                time.sleep(1)
        
        resp = requests.post('http://localhost:18188/prompt', json={'prompt': workflow})
        if resp.status_code != 200:
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()['prompt_id']
        print(f"[Worker] Prompt ID: {prompt_id}")
        
        # ✅ УВЕЛИЧЕННЫЙ ТАЙМАУТ: 20 минут вместо 5
        timeout = 1200
        start = time.time()
        check_count = 0
        
        while time.time() - start < timeout:
            check_count += 1
            elapsed = int(time.time() - start)
            
            try:
                resp = requests.get(f'http://localhost:18188/history/{prompt_id}')
                data = resp.json()
                
                if data.get(prompt_id):
                    outputs = data[prompt_id]['outputs']
                    print(f"[Worker] Проверка #{check_count} ({elapsed}s): Found outputs with keys: {list(outputs.keys())}")
                    
                    # Поиск видео в outputs
                    for node_id, node_output in outputs.items():
                        if 'videos' in node_output and node_output['videos']:
                            video_filename = node_output['videos'][0]['filename']
                            print(f"[Worker] ✅ Found video in node {node_id}: {video_filename}")
                            
                            # Ищем видео на диске
                            video_path = f'/workspace/ComfyUI/output/{video_filename}'
                            
                            # Ждём пока файл появится и будет полным
                            file_wait_count = 0
                            while file_wait_count < 60:
                                if os.path.exists(video_path):
                                    file_size = os.path.getsize(video_path)
                                    print(f"[Worker] File exists: {file_size} bytes")
                                    
                                    if file_size > 5000000:  # > 5MB - файл достаточно большой
                                        print(f"[Worker] ✅ Video file ready: {video_path}")
                                        
                                        # Читаем видео
                                        with open(video_path, 'rb') as f:
                                            video_bytes = f.read()
                                        
                                        video_b64 = base64.b64encode(video_bytes).decode()
                                        
                                        print(f"[Worker] ✅ Video encoded: {file_size} bytes -> {len(video_b64)} chars")
                                        
                                        return jsonify({
                                            'success': True,
                                            'video_filename': video_filename,
                                            'video_base64': video_b64,
                                            'file_size': file_size,
                                            'elapsed': elapsed
                                        }), 200
                                
                                file_wait_count += 1
                                time.sleep(1)
                            
                            print(f"[Worker] ❌ Video file not found or too small: {video_path}")
                            return jsonify({'error': f'Video file not found: {video_path}'}), 500
                    
                    print(f"[Worker] Проверка #{check_count} ({elapsed}s): No videos in outputs yet")
                else:
                    if check_count % 6 == 0:  # Логируем каждые 10 сек
                        print(f"[Worker] Проверка #{check_count} ({elapsed}s): Waiting for generation...")
                        
            except Exception as e:
                print(f"[Worker] Error checking history: {e}")
            
            time.sleep(2)  # Проверяем каждые 2 сек
        
        # FALLBACK: Поиск на диске если история не помогла
        print(f"[Worker] History timeout after {timeout}s, searching on disk...")
        for attempt in range(30):
            videos = glob.glob('/workspace/ComfyUI/output/**/*.mp4', recursive=True)
            if videos:
                latest_video = max(videos, key=os.path.getctime)
                filename = os.path.basename(latest_video)
                file_size = os.path.getsize(latest_video)
                
                print(f"[Worker] ✅ Found video on disk: {filename} ({file_size} bytes)")
                
                with open(latest_video, 'rb') as f:
                    video_bytes = f.read()
                
                video_b64 = base64.b64encode(video_bytes).decode()
                
                return jsonify({
                    'success': True,
                    'video_filename': filename,
                    'video_base64': video_b64,
                    'file_size': file_size
                }), 200
            
            print(f"[Worker] Disk search attempt {attempt+1}/30...")
            time.sleep(2)
        
        return jsonify({'error': 'Timeout waiting for video (1200s exceeded)'}), 500
        
    except Exception as e:
        print(f"[Worker] ❌ ERROR: {e}")
        print(traceback.format_exc())
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("Starting worker on port 8289...")
    app.run(host='0.0.0.0', port=8289, debug=False)
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
