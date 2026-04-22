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
    "https://github.com/yolain/ComfyUI-Easy-Use.git" \
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
do
    dir=$(basename "$repo" .git)
    if [ ! -d "$dir" ]; then
        git clone "$repo"
        cd "$dir"
        /venv/main/bin/pip install -r requirements.txt 2>/dev/null || true
        cd ..
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
    gguf ftfy einops sentencepiece protobuf \
    numba scipy imageio imageio-ffmpeg numexpr

echo "=== Dependencies installed ==="

# Создаём папку для видео
mkdir -p /workspace/ComfyUI/output/video

# Создаём worker.py на порту 8289 с поддержкой авторизации
cat > /workspace/ComfyUI/worker.py << 'EOF'
import json, base64, time, os, requests, glob
from flask import Flask, request, jsonify

app = Flask(__name__)

COMFYUI_URL = "http://localhost:18188"

# Получаем токен для авторизации
VAST_TOKEN = os.environ.get("OPEN_BUTTON_TOKEN", "")
auth = None
if VAST_TOKEN:
    auth = requests.auth.HTTPBasicAuth('vastai', VAST_TOKEN)
    print(f"✅ Using token authentication (token: {VAST_TOKEN[:20]}...)")
else:
    print("⚠️ No token found, proceeding without authentication")

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
        
        # Принудительно создаём папку input
        os.system("rm -rf /workspace/ComfyUI/input")
        os.makedirs("/workspace/ComfyUI/input", exist_ok=True)
        img_path = "/workspace/ComfyUI/input/temp.jpg"
        with open(img_path, "wb") as f:
            f.write(base64.b64decode(img_b64))
        print(f"✅ Image saved: {img_path}")
        
        # Обновляем ноду LoadImage (148)
        if "148" in workflow:
            workflow["148"]["inputs"]["image"] = "temp.jpg"
            print("✅ Updated node 148")
        
        # Ждём ComfyUI
        for i in range(60):
            try:
                requests.get(f"{COMFYUI_URL}/", timeout=2, auth=auth)
                print(f"✅ ComfyUI ready after {i+1} attempts")
                break
            except:
                time.sleep(1)
        
        # Отправляем запрос
        resp = requests.post(f"{COMFYUI_URL}/prompt", json={"prompt": workflow}, auth=auth)
        if resp.status_code != 200:
            return jsonify({'error': f'ComfyUI error: {resp.text}'}), 500
        
        prompt_id = resp.json()["prompt_id"]
        print(f"✅ Prompt ID: {prompt_id}")
        
        # Ждём результат
        timeout = 600
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                hist = requests.get(f"{COMFYUI_URL}/history/{prompt_id}", auth=auth).json()
                if hist.get(prompt_id):
                    outputs = hist[prompt_id]["outputs"]
                    print(f"=== OUTPUTS ===")
                    print(json.dumps(outputs, indent=2))
                    
                    for node_id, node_output in outputs.items():
                        if 'videos' in node_output and node_output['videos']:
                            v = node_output['videos'][0]
                            subfolder = v.get('subfolder', '')
                            if subfolder:
                                return jsonify({"video_url": f"{COMFYUI_URL}/view?filename={v['filename']}&subfolder={subfolder}"})
                            return jsonify({"video_url": f"{COMFYUI_URL}/view?filename={v['filename']}"})
                        if 'video' in node_output and node_output['video']:
                            v = node_output['video'][0]
                            subfolder = v.get('subfolder', '')
                            if subfolder:
                                return jsonify({"video_url": f"{COMFYUI_URL}/view?filename={v['filename']}&subfolder={subfolder}"})
                            return jsonify({"video_url": f"{COMFYUI_URL}/view?filename={v['filename']}"})
                    
                    # Поиск на диске
                    print("🔍 Looking for video on disk...")
                    for f in glob.glob("/workspace/ComfyUI/output/**/*.mp4", recursive=True):
                        if os.path.isfile(f) and not os.path.islink(f):
                            video_filename = os.path.basename(f)
                            subfolder = os.path.basename(os.path.dirname(f))
                            print(f"✅ Found video: {video_filename} in {subfolder}")
                            return jsonify({"video_url": f"{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}"})
                                        # ПРЯМОЙ ПОИСК ВИДЕО
                    print("🔍 FORCED VIDEO SEARCH...")
                    video_file = "/workspace/ComfyUI/output/video/ComfyUI_00001_.mp4"
                    if os.path.exists(video_file):
                        real_path = os.path.realpath(video_file)
                        if os.path.exists(real_path):
                            video_filename = os.path.basename(real_path)
                            subfolder = os.path.basename(os.path.dirname(real_path))
                            print(f"✅ Found video: {video_filename} in {subfolder}")
                            return jsonify({"video_url": f"{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}"})
                    return jsonify({'error': 'Video not found'}), 500
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(2)
        
        return jsonify({'error': 'Timeout'}), 500
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == "__main__":
    print("Starting worker on port 8289...")
    app.run(host="0.0.0.0", port=8289)
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
pkill -f worker.py 2>/dev/null || true
nohup /venv/main/bin/python /workspace/ComfyUI/worker.py > /workspace/worker.log 2>&1 &

sleep 5

# Проверяем worker
if curl -s http://localhost:8289/ > /dev/null 2>&1; then
    echo "✅ Worker started on port 8289"
else
    echo "⚠️ Worker may not be ready yet"
    tail -20 /workspace/worker.log
fi

echo "=== Provisioning complete ==="
