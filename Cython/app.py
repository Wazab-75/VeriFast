from flask import Flask, render_template, request, jsonify, send_file
import numpy as np
from PIL import Image
import io
import os
from mandelbrot_generator import generate_image
from julia_generator import generate_julia_image

app = Flask(__name__)
performance_log = []  # Track performance of Mandelbrot renders

# Check FPGA availability
FPGA_AVAILABLE = False
try:
    from pynq import Overlay
    from pynq.lib.video import *
    if os.path.exists("/home/xilinx/elec50015.bit"):
        overlay = Overlay("/home/xilinx/elec50015.bit")
        imgen_vdma = overlay.video.axi_vdma_0.readchannel
        pixgen = overlay.pixel_generator_0
        
        # Configure video mode
        videoMode = common.VideoMode(640, 480, 24)
        imgen_vdma.mode = videoMode
        imgen_vdma.start()
        FPGA_AVAILABLE = True
        print("FPGA overlay loaded successfully")
    else:
        print("FPGA bitstream file not found")
except Exception as e:
    print(f"Error initializing FPGA: {e}")
    overlay = None

@app.route('/')
def index():
    return render_template('index.html', fpga_available=FPGA_AVAILABLE)

@app.route('/generate', methods=['POST'])
def generate_mandelbrot():
    try:
        data = request.json
        if not data:
            return "No data provided", 400

        # Get version from request
        version = data.get('version', 'software')

        if version == 'hardware':
            if not FPGA_AVAILABLE:
                return "FPGA not available", 503
            try:
                # Read frame from FPGA
                frame = imgen_vdma.readframe()
                
                # Convert to image
                img = Image.fromarray(frame)
                img_byte_arr = io.BytesIO()
                img.save(img_byte_arr, format='PNG')
                img_byte_arr.seek(0)
                
                performance_log.append({
                    'type': 'mandelbrot',
                    'version': 'hardware',
                    'resolution': '640x480',
                    'time': 0  # FPGA is instant
                })
                
                return send_file(img_byte_arr, mimetype='image/png')
            except Exception as e:
                print(f"Error reading from FPGA: {e}")
                return "Error reading from FPGA", 500
        else:
            return generate_software_mandelbrot(data)

    except Exception as e:
        print("Error generating Mandelbrot:", e)
        return str(e), 500

def generate_software_mandelbrot(data):
    """Generate Mandelbrot set using CPU"""
    required = ['width', 'height', 'max_iter', 'zoom', 'center_x', 'center_y']
    for param in required:
        if param not in data:
            return f"Missing required parameter: {param}", 400

    # Parse and validate
    width = int(data['width'])
    height = int(data['height'])
    max_iter = int(data['max_iter'])
    zoom = float(data['zoom'])
    cx = float(data['center_x'])
    cy = float(data['center_y'])
    cmap = data.get('cmap', 'hot')

    if width <= 0 or height <= 0 or max_iter <= 0 or zoom <= 0:
        return "Invalid parameters", 400

    # Generate Mandelbrot image
    buf, elapsed = generate_image(width, height, max_iter, zoom, cx, cy, cmap)
    performance_log.append({
        'type': 'mandelbrot',
        'version': 'software',
        'resolution': f'{width}x{height}',
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
        zx = float(data.get('zx', 0.0))  # View center
        zy = float(data.get('zy', 0.0))
        c_real = float(data['center_x'])  # Used as Julia constant
        c_imag = float(data['center_y'])
        cmap = data.get('cmap', 'hot')

        if width <= 0 or height <= 0 or max_iter <= 0 or zoom <= 0:
            return "Invalid parameters", 400

        c = complex(c_real, c_imag)
        buf, elapsed = generate_julia_image(width, height, max_iter, zoom, zx, zy, c, cmap)

        performance_log.append({
            'type': 'julia',
            'resolution': f'{width}x{height}',
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
    app.run(debug=True)
