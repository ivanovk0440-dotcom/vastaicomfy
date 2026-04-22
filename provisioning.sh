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

# Создаём worker.py на порту 8288 (ИСПРАВЛЕННАЯ ВЕРСИЯ)
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json, base64, time, os, requests
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
        
        # === ИСПРАВЛЕНИЕ №1: Правильный путь к полю image ===
        if '148' in workflow:
            workflow['148']['inputs']['image'] = 'temp.jpg'
        else:
            # Fallback: ищем любую ноду LoadImage
            for node_id, node in workflow.items():
                if node.get('class_type') == 'LoadImage':
                    node['inputs']['image'] = 'temp.jpg'
                    break
        
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
        
        timeout = 300
        start = time.time()
        while time.time() - start < timeout:
            try:
                resp = requests.get(f'http://localhost:18188/history/{prompt_id}')
                data = resp.json()
                if data.get(prompt_id):
                    outputs = data[prompt_id]['outputs']
                    for node_id, node_output in outputs.items():
                        if 'videos' in node_output:
                            # === ИСПРАВЛЕНИЕ №2: Правильное формирование URL с subfolder и type ===
                            video_info = node_output['videos'][0]
                            video_filename = video_info['filename']
                            subfolder = video_info.get('subfolder', '')
                            video_type = video_info.get('type', 'output')
                            
                            # Формируем корректный URL для скачивания
                            url = f"http://localhost:18188/view?filename={video_filename}&subfolder={subfolder}&type={video_type}"
                            return jsonify({'video_url': url})
            except:
                pass
            time.sleep(2)
        
        return jsonify({'error': 'Timeout waiting for video'}), 500
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("Starting worker on port 8288...")
    app.run(host='0.0.0.0', port=8288)
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

# Запускаем worker на порту 8288
cd /workspace/ComfyUI
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

sleep 5

# Проверяем worker
if curl -s http://localhost:8288/ > /dev/null 2>&1; then
    echo "✅ Worker started on port 8288"
else
    echo "⚠️ Worker may not be ready yet"
fi

echo "=== Provisioning complete ==="
