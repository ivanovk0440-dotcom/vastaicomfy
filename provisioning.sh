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
