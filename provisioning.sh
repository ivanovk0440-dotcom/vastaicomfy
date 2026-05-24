#!/bin/bash
set -e

echo "=== Starting provisioning ==="
cd /workspace/ComfyUI

# 1. Создаём папки для моделей
mkdir -p models/diffusion_models
mkdir -p models/text_encoders
mkdir -p models/vae
mkdir -p models/loras
mkdir -p models/rife

# 2. Загрузка моделей (используем wget -c, чтобы докачивать в случае обрыва)
echo "=== Checking Models ==="
wget -c -q --show-progress -O models/vae/wan_2.1_vae.safetensors "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=1"
wget -c -q --show-progress -O models/text_encoders/nsfw_wan_umt5-xxl_fp8_scaled.safetensors "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors?download=1"
wget -c -q --show-progress -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors?download=1"
wget -c -q --show-progress -O models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors?download=1"
wget -c -q --show-progress -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_HIGH_fp16.safetensors?download=1"
wget -c -q --show-progress -O models/loras/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22-Lightning/old/Wan2.2-Lightning_I2V-A14B-4steps-lora_LOW_fp16.safetensors?download=1"
wget -c -q --show-progress -O models/rife/rife47.pth "https://huggingface.co/jasonot/mycomfyui/resolve/main/rife47.pth?download=1"

# 3. Установка и обновление кастомных нод
echo "=== Installing/Updating custom nodes ==="
cd /workspace/ComfyUI/custom_nodes

REPOS=(
    "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    "https://github.com/kijai/ComfyUI-KJNodes.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
)

for repo in "${REPOS[@]}"; do
    dir=$(basename "$repo" .git)
    if [ -d "$dir" ]; then
        echo "Updating $dir..."
        cd "$dir"
        git reset --hard  # Удаляем старые неудачные правки sed
        git fetch
        git pull
        cd ..
    else
        echo "Cloning $dir..."
        git clone "$repo"
    fi
done

# 4. БЕЗОПАСНЫЙ ПАТЧ ошибки multitalk_audio_stride через Python
echo "=== Patching nodes_sampler.py ==="
/venv/main/bin/python3 << 'EOF'
import os

file_path = '/workspace/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper/nodes_sampler.py'
if os.path.exists(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    patched = False
    for line in lines:
        new_lines.append(line)
        # Ищем начало функции process и вставляем фикс сразу после неё
        if 'def process(' in line and not patched:
            # Используем 8 пробелов для отступа (стандарт для методов класса)
            indent = "        " 
            new_lines.append(f"{indent}multitalk_audio_stride = None\n")
            patched = True
            print("✅ Successfully patched nodes_sampler.py")

    if patched:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
    else:
        print("⚠️ Could not find 'def process(' to patch")
else:
    print("❌ nodes_sampler.py not found")
EOF

# 5. Установка зависимостей
echo "=== Installing dependencies ==="
/venv/main/bin/pip install --quiet --upgrade pip
/venv/main/bin/pip install --quiet \
    flask requests opencv-python opencv-python-headless \
    accelerate transformers diffusers peft \
    gguf ftfy einops sentencepiece protobuf

# Доп. зависимости для WanVideo
if [ -f "ComfyUI-WanVideoWrapper/requirements.txt" ]; then
    /venv/main/bin/pip install --quiet -r ComfyUI-WanVideoWrapper/requirements.txt
fi

# 6. Создание worker.py
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json, base64, time, os, requests, traceback, sys
from flask import Flask, request, jsonify

app = Flask(__name__)

def log(msg):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [Worker] {msg}", flush=True)

@app.route('/generate/sync', methods=['POST'])
def generate():
    try:
        log("=== NEW REQUEST ===")
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
        
        # Ждем ComfyUI
        for _ in range(30):
            try:
                requests.get('http://localhost:18188/', timeout=2)
                break
            except:
                time.sleep(1)
        
        resp = requests.post('http://localhost:18188/prompt', json={'prompt': workflow})
        if resp.status_code != 200:
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()['prompt_id']
        log(f"✅ Prompt ID: {prompt_id}")
        
        start = time.time()
        while time.time() - start < 1200:
            try:
                history_resp = requests.get(f'http://localhost:18188/history/{prompt_id}')
                history = history_resp.json()
                
                if history.get(prompt_id):
                    outputs = history[prompt_id]['outputs']
                    for node_id, node_output in outputs.items():
                        for key in ['videos', 'images']:
                            if key in node_output:
                                for item in node_output[key]:
                                    filename = item['filename']
                                    sub = item.get('subfolder', '')
                                    v_path = f'/workspace/ComfyUI/output/{sub}/{filename}' if sub else f'/workspace/ComfyUI/output/{filename}'
                                    
                                    if os.path.exists(v_path) and os.path.getsize(v_path) > 100000:
                                        with open(v_path, 'rb') as f:
                                            v_b64 = base64.b64encode(f.read()).decode()
                                        return jsonify({
                                            'success': True,
                                            'video_base64': v_b64,
                                            'elapsed': int(time.time() - start)
                                        }), 200
            except:
                pass
            time.sleep(2)
        return jsonify({'error': 'Timeout'}), 500
    except Exception as e:
        log(f"❌ ERROR: {traceback.format_exc()}")
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8289, threaded=True)
EOF

# 7. Запуск
echo "=== Starting Worker ==="
pkill -f worker.py || true
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

echo "=== Provisioning complete ==="
