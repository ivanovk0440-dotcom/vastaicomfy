#!/usr/bin/env python3
# worker.py

import json
import base64
import tempfile
import os
import uuid
from vastai import Worker, WorkerConfig, HandlerConfig
from PIL import Image
import io

# Путь к твоему JSON-воркфлоу
WORKFLOW_PATH = "/workspace/workflow.json"

def load_base_workflow():
    with open(WORKFLOW_PATH, "r") as f:
        return json.load(f)

def request_parser(raw_payload):
    workflow = load_base_workflow()
    
    # 1. Подставляем промпты
    workflow["134"]["widgets_values"][0] = raw_payload.get("prompt", "a beautiful landscape")
    workflow["137"]["widgets_values"][0] = raw_payload.get("negative_prompt", "low quality, blurry")
    
    # 2. Подставляем шаги
    steps = raw_payload.get("steps", 8)
    workflow["150"]["widgets_values"][0] = steps
    workflow["151"]["widgets_values"][0] = steps // 2
    
    # 3. Обрабатываем входное изображение
    if "image_base64" in raw_payload:
        # Декодируем base64
        image_data = base64.b64decode(raw_payload["image_base64"])
        image = Image.open(io.BytesIO(image_data))
        
        # Сохраняем во временный файл
        image_filename = f"input_{uuid.uuid4().hex}.jpg"
        image_path = f"/workspace/ComfyUI/input/{image_filename}"
        
        # Создаем папку если нет
        os.makedirs("/workspace/ComfyUI/input", exist_ok=True)
        
        image.save(image_path)
        
        # Подставляем в воркфлоу (нода LoadImage)
        workflow["148"]["widgets_values"][0] = image_filename
    
    # 4. Настройки разрешения (опционально)
    if "width" in raw_payload:
        workflow["147"]["widgets_values"][0] = raw_payload["width"]
    
    # Возвращаем для отправки в ComfyUI
    return {"workflow_json": workflow}

def response_parser(raw_response):
    """Обрабатываем результат генерации"""
    # raw_response содержит путь к сгенерированному видео
    video_path = raw_response.get("video_path")
    
    if video_path and os.path.exists(video_path):
        with open(video_path, "rb") as f:
            video_base64 = base64.b64encode(f.read()).decode()
        return {
            "status": "success",
            "video_base64": video_base64
        }
    else:
        return {
            "status": "error",
            "message": "Video generation failed"
        }

# Настройка обработчика
handler = HandlerConfig(
    route="/generate",  # Эндпоинт для бота
    request_parser=request_parser,
    response_parser=response_parser,
    workload_calculator=lambda payload: 1.0,  # Можно настроить вес
)

worker_config = WorkerConfig(
    model_server_url="http://localhost:18188",  # ComfyUI API
    model_server_port=8188,
    handlers=[handler],
)

if __name__ == "__main__":
    Worker(worker_config).run()