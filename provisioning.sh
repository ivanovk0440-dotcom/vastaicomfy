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
        
        # Ждём ComfyUI на localhost:18188
        print("Waiting for ComfyUI on localhost:18188...")
        comfy_ready = False
        for i in range(60):
            try:
                resp = requests.get('http://localhost:18188/', timeout=2)
                if resp.status_code == 200:
                    print(f"ComfyUI ready after {i+1} attempts")
                    comfy_ready = True
                    break
                else:
                    print(f"  Attempt {i+1}: status {resp.status_code}")
            except Exception as e:
                print(f"  Attempt {i+1}: {str(e)[:50]}")
            time.sleep(10)
        
        if not comfy_ready:
            return jsonify({'error': 'ComfyUI not ready after 10 minutes'}), 500
        
        # Отправляем промпт в ComfyUI
        print("Sending prompt to ComfyUI...")
        resp = requests.post('http://localhost:18188/prompt', json={'prompt': workflow})
        if resp.status_code != 200:
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()['prompt_id']
        print(f"Prompt ID: {prompt_id}")
        
        # Ждём результат до 20 минут
        timeout = 1200
        start = time.time()
        last_log_time = start
        
        while time.time() - start < timeout:
            try:
                resp = requests.get(f'http://localhost:18188/history/{prompt_id}')
                data = resp.json()
                
                # Логируем статус каждые 30 секунд
                if time.time() - last_log_time > 30:
                    elapsed = int(time.time() - start)
                    print(f"  Waiting... {elapsed}s elapsed")
                    last_log_time = time.time()
                
                if data.get(prompt_id):
                    outputs = data[prompt_id]['outputs']
                    print(f"Got outputs! Keys: {list(outputs.keys())}")
                    print(f"Full outputs: {json.dumps(outputs, indent=2)}")
                    
                    # Ищем видео в outputs
                    for node_id, node_output in outputs.items():
                        if 'videos' in node_output:
                            videos = node_output['videos']
                            print(f"Found videos in node {node_id}: {videos}")
                            video_filename = videos[0]['filename']
                            return jsonify({
                                'video_filename': video_filename,
                                'video_url': f'http://localhost:18188/view?filename={video_filename}'
                            })
                        
                        if 'gifs' in node_output:
                            gifs = node_output['gifs']
                            print(f"Found gifs in node {node_id}: {gifs}")
                            video_filename = gifs[0]['filename']
                            return jsonify({
                                'video_filename': video_filename,
                                'video_url': f'http://localhost:18188/view?filename={video_filename}'
                            })
                    
                    # Ищем видео на диске
                    print("No video in outputs, searching disk...")
                    search_dirs = [
                        '/workspace/ComfyUI/output/video',
                        '/workspace/ComfyUI/output',
                        '/workspace/ComfyUI/output/video/ComfyUI'
                    ]
                    
                    for search_dir in search_dirs:
                        if os.path.exists(search_dir):
                            mp4_files = glob.glob(f'{search_dir}/**/*.mp4', recursive=True)
                            if mp4_files:
                                latest = max(mp4_files, key=os.path.getctime)
                                print(f"Found video on disk: {latest}")
                                # Формируем правильный относительный путь для view
                                rel_path = os.path.relpath(latest, '/workspace/ComfyUI/output')
                                return jsonify({
                                    'video_filename': rel_path,
                                    'video_url': f'http://localhost:18188/view?filename={rel_path}'
                                })
                    
                    return jsonify({'error': 'No video found', 'outputs': outputs}), 500
                    
            except Exception as e:
                print(f"  Check error: {str(e)[:100]}")
            time.sleep(3)
        
        return jsonify({'error': f'Timeout waiting for video after {timeout}s'}), 500
        
    except Exception as e:
        print(f"Worker error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    print("Starting worker on port 8289...")
    app.run(host='0.0.0.0', port=8289)
EOF

echo "=== Worker script created ==="

# Ждём ComfyUI
echo "Waiting for ComfyUI to be ready on port 18188..."
for i in {1..60}; do
    if curl -s http://localhost:18188/ > /dev/null 2>&1; then
        echo "ComfyUI is ready on port 18188!"
        break
    fi
    echo "  Attempt $i/60 - waiting..."
    sleep 10
done

# Проверяем что порт слушается
echo "Checking listening ports:"
netstat -tlnp 2>/dev/null | grep -E '18188|8289' || ss -tlnp | grep -E '18188|8289'

# Запускаем worker на порту 8289
echo "Starting worker..."
cd /workspace/ComfyUI
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

sleep 5

# Проверяем worker
echo "Checking worker..."
if curl -s http://localhost:8289/health > /dev/null 2>&1; then
    echo "✅ Worker started on port 8289"
else
    echo "⚠️ Worker may not be ready yet, checking logs:"
    tail -20 /workspace/worker.log
fi

echo "=== Provisioning complete ==="

# Удаляем флаг
rm -f /.provisioning
