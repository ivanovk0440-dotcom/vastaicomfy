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

# Создаём worker.py (ОКОНЧАТЕЛЬНО ИСПРАВЛЕННАЯ ВЕРСИЯ)
echo "=== Creating worker.py ==="
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json, base64, time, os, requests, glob
from flask import Flask, request, jsonify

app = Flask(__name__)

COMFYUI_PORT = 18188
COMFYUI_URL = f"http://localhost:{COMFYUI_PORT}"

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
        
        # Сохраняем картинку (ИСПРАВЛЕНО)
        input_dir = '/workspace/ComfyUI/input'
        if os.path.exists(input_dir) and not os.path.isdir(input_dir):
            os.remove(input_dir)
        os.makedirs(input_dir, exist_ok=True)
        img_path = os.path.join(input_dir, 'temp.jpg')
        with open(img_path, 'wb') as f:
            f.write(base64.b64decode(img_b64))
        print(f"✅ Image saved: {img_path}")
        
        # Обновляем ноду LoadImage (148)
        if "148" in workflow:
            if "inputs" not in workflow["148"]:
                workflow["148"]["inputs"] = {}
            workflow["148"]["inputs"]["image"] = "temp.jpg"
        
        # Ждём ComfyUI
        for i in range(60):
            try:
                requests.get(f'{COMFYUI_URL}/', timeout=2)
                print(f"✅ ComfyUI ready after {i+1} attempts")
                break
            except:
                pass
            time.sleep(1)
        
        # Отправляем запрос
        resp = requests.post(f'{COMFYUI_URL}/prompt', json={'prompt': workflow})
        if resp.status_code != 200:
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()['prompt_id']
        print(f"✅ Prompt ID: {prompt_id}")
        
        # Ждём результат
        timeout = 600
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                resp = requests.get(f'{COMFYUI_URL}/history/{prompt_id}')
                data = resp.json()
                if data.get(prompt_id):
                    outputs = data[prompt_id]['outputs']
                    print(f"=== OUTPUTS ===")
                    print(json.dumps(outputs, indent=2))
                    print(f"==============")
                    
                    for node_id, node_output in outputs.items():
                        if 'videos' in node_output and node_output['videos']:
                            video_filename = node_output['videos'][0]['filename']
                            subfolder = node_output['videos'][0].get('subfolder', '')
                            if subfolder:
                                return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}'})
                            return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}'})
                        if 'video' in node_output and node_output['video']:
                            video_filename = node_output['video'][0]['filename']
                            subfolder = node_output['video'][0].get('subfolder', '')
                            if subfolder:
                                return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}'})
                            return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}'})
                        if 'images' in node_output and node_output['images']:
                            print(f"  Found images in node {node_id}: {len(node_output['images'])}")
                            image_filename = node_output['images'][0]['filename']
                            subfolder = node_output['images'][0].get('subfolder', '')
                            if subfolder:
                                return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={image_filename}&subfolder={subfolder}'})
                            return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={image_filename}'})
                    
                    # Если видео не найдено в outputs, ищем на диске
                    print("🔍 Looking for video on disk...")
                    
                    # Вариант 1: через симлинк
                    video_link = '/workspace/ComfyUI/output/video/ComfyUI_00001_.mp4'
                    if os.path.exists(video_link):
                        real_path = os.path.realpath(video_link)
                        if os.path.exists(real_path):
                            video_filename = os.path.basename(real_path)
                            subfolder = os.path.basename(os.path.dirname(real_path))
                            print(f"✅ Found video via symlink: {video_filename} in {subfolder}")
                            return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}'})
                    
                    # Вариант 2: через UUID папки
                    output_dirs = glob.glob('/workspace/ComfyUI/output/*/')
                    if output_dirs:
                        latest_dir = max(output_dirs, key=os.path.getctime)
                        video_files = glob.glob(f'{latest_dir}/*.mp4')
                        if video_files:
                            video_filename = os.path.basename(video_files[0])
                            subfolder = os.path.basename(latest_dir.rstrip('/'))
                            print(f"✅ Found video in UUID folder: {video_filename} in {subfolder}")
                            return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}'})
                    
                    print("⚠️ Video not found")
                    return jsonify({'error': 'Video not found'}), 500
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(2)
        
        return jsonify({'error': 'Timeout waiting for video'}), 500
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print(f"Starting worker on port 8288, ComfyUI at {COMFYUI_URL}")
    app.run(host='0.0.0.0', port=8288)
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
