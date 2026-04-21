# После проверки outputs, если видео не найдено
print("🔍 Ищем видео на диске...")

# Вариант 1: Ищем через симлинк в video/
video_link = '/workspace/ComfyUI/output/video/ComfyUI_00001_.mp4'
if os.path.exists(video_link):
    real_path = os.path.realpath(video_link)
    if os.path.exists(real_path):
        video_filename = os.path.basename(real_path)
        subfolder = os.path.basename(os.path.dirname(real_path))
        print(f"✅ Найдено видео через симлинк: {video_filename} в {subfolder}")
        return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}'})

# Вариант 2: Ищем все свежие папки с UUID
import glob
output_dirs = glob.glob('/workspace/ComfyUI/output/*/')
if output_dirs:
    latest_dir = max(output_dirs, key=os.path.getctime)
    video_files = glob.glob(f'{latest_dir}/*.mp4')
    if video_files:
        video_filename = os.path.basename(video_files[0])
        subfolder = os.path.basename(latest_dir.rstrip('/'))
        print(f"✅ Найдено видео в папке: {video_filename} в {subfolder}")
        return jsonify({'video_url': f'{COMFYUI_URL}/view?filename={video_filename}&subfolder={subfolder}'})
