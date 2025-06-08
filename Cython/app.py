# -*- coding: utf-8 -*-
from flask import Flask, request, jsonify, send_file
import numpy as np
from PIL import Image
import os
import time
from mandelbrot_generator import generate_image
from julia_generator import generate_julia_image

# Helpers to clamp to 32-bit fixed-point
def to_q8_24(val: float) -> int:
    return int(val * (1 << 24)) & 0xFFFFFFFF

def u32(val: int) -> int:
    return val & 0xFFFFFFFF

app = Flask(__name__)
performance_log = []

FPGA_AVAILABLE = False
try:
    from pynq import Overlay
    from pynq.lib.video import *

    overlay_path = "/home/xilinx/overlays/pixel_generator/elec50015.bit"
    overlay = Overlay(overlay_path)

    imgen_vdma = overlay.video.axi_vdma_0.readchannel
    pixgen = overlay.pixel_generator_0

    videoMode = common.VideoMode(640, 480, 24)
    imgen_vdma.mode = videoMode
    imgen_vdma.start()

    FPGA_AVAILABLE = True
    print("FPGA overlay loaded successfully")
except Exception as e:
    print(f"Error initializing FPGA: {e}")
    overlay = None

@app.route('/')
def index():
    return "PYNQ compute backend is running", 200

@app.route('/debug_hw_frame', methods=['GET'])
def debug_hw_frame():
    if not FPGA_AVAILABLE:
        return "FPGA not available", 503

    try:
        time.sleep(0.5)
        frame = imgen_vdma.readframe()
        img = Image.fromarray(frame)

        # Save to static path (Flask-safe)
        img_path = "/tmp/hw_debug_output.png"
        img.save(img_path)

        return send_file(img_path, mimetype='image/png')

    except Exception as e:
        print(f"[ERROR] Debug read failed: {e}")
        return f"Hardware debug error: {str(e)}", 500



@app.route('/generate', methods=['POST'])
def generate_mandelbrot():
    try:
        data = request.json
        if not data:
            return "No data provided", 400

        version = data.get('version', 'software')

        if version == 'hardware':
            if not FPGA_AVAILABLE:
                return "FPGA not available", 503
            try:
                width = int(data.get('width', 640))
                height = int(data.get('height', 480))
                zoom = float(data.get('zoom', 1.0))
                cx = float(data.get('center_x', 0.0))
                cy = float(data.get('center_y', 0.0))
                max_iter = int(data.get('max_iter', 300))

                BASE_STEP_FIXED = 0x1999A
                step_fixed = int(BASE_STEP_FIXED / zoom)

                cx_fixed = to_q8_24(cx)
                cy_fixed = to_q8_24(cy)

                top_left_x = u32(cx_fixed - ((step_fixed * (width // 2)) >> 24))
                top_left_y = u32(cy_fixed - ((step_fixed * (height // 2)) >> 24))

                pixgen.write(0x04, top_left_x)
                pixgen.write(0x08, top_left_y)
                pixgen.write(0x0C, u32(step_fixed))
                pixgen.write(0x10, u32(max_iter))
                pixgen.write(0x00, 1)

                time.sleep(0.5)

                frame = imgen_vdma.readframe()
                img = Image.fromarray(frame)
                img_path = "/tmp/hw_generated_output.png"
                img.save(img_path)
                return send_file(img_path, mimetype='image/png')

            except Exception as e:
                print(f"[ERROR] Hardware render failed: {e}")
                return f"Hardware error: {str(e)}", 500
        else:
            return generate_software_mandelbrot(data)

    except Exception as e:
        print("Error generating Mandelbrot:", e)
        return str(e), 500

def generate_software_mandelbrot(data):
    required = ['width', 'height', 'max_iter', 'zoom', 'center_x', 'center_y']
    for param in required:
        if param not in data:
            return f"Missing required parameter: {param}", 400

    width = int(data['width'])
    height = int(data['height'])
    max_iter = int(data['max_iter'])
    zoom = float(data['zoom'])
    cx = float(data['center_x'])
    cy = float(data['center_y'])
    cmap = data.get('cmap', 'hot')

    if width <= 0 or height <= 0 or max_iter <= 0 or zoom <= 0:
        return "Invalid parameters", 400

    buf, elapsed = generate_image(width, height, max_iter, zoom, cx, cy, cmap)

    performance_log.append({
        'type': 'mandelbrot',
        'version': 'software',
        'resolution': f'{width}x{height}',
        'zoom': zoom,
        'center': f'({cx}, {cy})',
        'max_iter': max_iter,
        'time': round(elapsed, 3)
    })

    return send_file(buf, mimetype='image/png')

@app.route('/generate_julia', methods=['POST'])
def generate_julia():
    try:
        data = request.json
        if not data:
            return "No data provided", 400

        required = ['width', 'height', 'max_iter', 'zoom', 'center_x', 'center_y']
        for param in required:
            if param not in data:
                return f"Missing required parameter: {param}", 400

        width = int(data['width'])
        height = int(data['height'])
        max_iter = int(data['max_iter'])
        zoom = float(data['zoom'])
        zx = float(data.get('zx', 0.0))
        zy = float(data.get('zy', 0.0))
        c_real = float(data['center_x'])
        c_imag = float(data['center_y'])
        cmap = data.get('cmap', 'hot')

        if width <= 0 or height <= 0 or max_iter <= 0 or zoom <= 0:
            return "Invalid parameters", 400

        c = complex(c_real, c_imag)
        buf, elapsed = generate_julia_image(width, height, max_iter, zoom, zx, zy, c, cmap)

        performance_log.append({
            'type': 'julia',
            'resolution': f'{width}x{height}',
            'zoom': zoom,
            'center': f'({c_real}, {c_imag})',
            'max_iter': max_iter,
            'time': round(elapsed, 3)
        })

        return send_file(buf, mimetype='image/png')

    except Exception as e:
        print("Error generating Julia:", e)
        return str(e), 500

@app.route('/performance')
def performance():
    return jsonify(performance_log)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=7003)
    
@app.route('/shutdown', methods=['POST'])
def shutdown():
    func = request.environ.get('werkzeug.server.shutdown')
    if func:
        print("[INFO] Shutting down Flask...")
        cleanup()
        func()
        return "Shutting down...", 200
    return "Not running with Werkzeug", 500

import atexit

def cleanup():
    if FPGA_AVAILABLE:
        try:
            print("[INFO] Stopping VDMA safely...")
            imgen_vdma.stop()
        except Exception as e:
            print(f"[WARN] VDMA stop failed: {e}")

        try:
            del overlay
        except:
            pass

atexit.register(cleanup)