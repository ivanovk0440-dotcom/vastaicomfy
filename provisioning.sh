#!/bin/bash
set -e

echo "=== Installing custom nodes ==="
cd /workspace/ComfyUI/custom_nodes

# WanVideo Wrapper
if [ ! -d "ComfyUI-WanVideoWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
    cd ComfyUI-WanVideoWrapper
    pip install -r requirements.txt
    cd ..
fi

# KJNodes
if [ ! -d "ComfyUI-KJNodes" ]; then
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
    cd ComfyUI-KJNodes
    pip install -r requirements.txt
    cd ..
fi

# Custom Scripts
if [ ! -d "cg-use-everywhere" ]; then
    git clone https://github.com/chrisgoringe/cg-use-everywhere.git
fi

# Frame Interpolation
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
    cd ComfyUI-Frame-Interpolation
    pip install -r requirements.txt
    cd ..
fi

echo "=== Provisioning complete ==="
