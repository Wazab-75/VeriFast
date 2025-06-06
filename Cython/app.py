from flask import Flask, request, jsonify, send_file
import numpy as np
from PIL import Image
import io
import os
from mandelbrot_generator import generate_image
from julia_generator import generate_julia_image

app = Flask(__name__)

performance_log = []

FPGA_AVAILABLE = False
try:
    from pynq import Overlay
    from pynq.lib.video import *

    overlay_path = "/home/xilinx/overlays/fractals/elec50015.bit"
    overlay = Overlay(overlay_path)

    # Replace these with actual IP names from mandelbrot.hwh if different
    imgen_vdma = overlay.video.axi_vdma_0.readchannel
    pixgen = overlay.pixel_generator_0

    # Set video mode for framebuffer
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
                zoom = int(float(data.get('zoom', 1.0)))         # plain int
                cx = float(data.get('center_x', 0.0))
                cy = float(data.get('center_y', 0.0))
                max_iter = int(data.get('max_iter', 300))

                # Convert Q8.24 format
                cx_fixed = int(cx * (1 << 24))
                cy_fixed = int(cy * (1 << 24))

                # Write to registers
                pixgen.write(0x04, cx_fixed)     # reg1 = center_x (Q8.24)
                pixgen.write(0x08, cy_fixed)     # reg2 = center_y (Q8.24)
                pixgen.write(0x0C, zoom)         # reg3 = zoom (int)
                pixgen.write(0x10, max_iter)     # reg4 = max_iter (int)

                # Optionally trigger if IP requires it (confirm with team)
                # pixgen.write(0x00, 1)  # reg0 = control?

                # Read framebuffer from VDMA
                frame = imgen_vdma.readframe()

                # Return image
                img = Image.fromarray(frame)
                img_byte_arr = io.BytesIO()
                img.save(img_byte_arr, format='PNG')
                img_byte_arr.seek(0)

                return send_file(img_byte_arr, mimetype='image/png')

            except Exception as e:
                print(f"Error in hardware generation: {e}")
                return "Hardware error", 500

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
    app.run(host='0.0.0.0', port=5005)
