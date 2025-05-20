from flask import Flask, request, render_template, send_file, jsonify
import numpy as np
import matplotlib.pyplot as plt
import io
import time

app = Flask(__name__)
performance_log = []  # Store (resolution, time) tuples

def mandelbrot(width, height, max_iter, cx, cy, zoom):
    # Create coordinate arrays
    scale_x = 3.5 / zoom
    scale_y = 2.0 / zoom
    xmin = cx - scale_x / 2
    xmax = cx + scale_x / 2
    ymin = cy - scale_y / 2
    ymax = cy + scale_y / 2
    
    # Create coordinate matrices
    x = np.linspace(xmin, xmax, width)
    y = np.linspace(ymin, ymax, height)
    c = x.reshape((1, width)) + 1j * y.reshape((height, 1))
    
    # Initialize arrays
    z = np.zeros_like(c, dtype=np.complex128)
    div_time = np.zeros(z.shape, dtype=np.int32)
    m = np.full(z.shape, True, dtype=bool)
    
    # Vectorized iteration
    for i in range(max_iter):
        z[m] = z[m] * z[m] + c[m]
        diverged = np.abs(z) > 2.0
        div_time[diverged & m] = i
        m[diverged] = False
        if not np.any(m):
            break
    
    # Normalize and convert to uint8
    img = (255 * div_time / max_iter).astype(np.uint8)
    return img

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/generate', methods=['POST'])
def generate():
    try:
        data = request.json
        if not data:
            return "No data provided", 400

        # Validate required parameters
        required_params = ['width', 'height', 'max_iter', 'zoom', 'center_x', 'center_y']
        for param in required_params:
            if param not in data:
                return f"Missing required parameter: {param}", 400

        # Parse and validate parameters
        try:
            width = int(data['width'])
            height = int(data['height'])
            max_iter = int(data['max_iter'])
            zoom = float(data['zoom'])
            cx = float(data['center_x'])
            cy = float(data['center_y'])
            cmap = data.get('cmap', 'hot')
        except (ValueError, TypeError) as e:
            return f"Invalid parameter value: {str(e)}", 400

        # Validate parameter ranges
        if width <= 0 or height <= 0:
            return "Width and height must be positive", 400
        if max_iter <= 0:
            return "Max iterations must be positive", 400
        if zoom <= 0:
            return "Zoom must be positive", 400

        start = time.time()
        img = mandelbrot(width, height, max_iter, cx, cy, zoom)
        elapsed = time.time() - start
        performance_log.append({'resolution': f'{width}x{height}', 'time': round(elapsed, 3)})

        buf = io.BytesIO()
        plt.imsave(buf, img, cmap=cmap, format='png')
        buf.seek(0)
        return send_file(buf, mimetype='image/png')

    except Exception as e:
        print(f"Error generating fractal: {str(e)}")
        return str(e), 500

@app.route('/performance')
def performance():
    return jsonify(performance_log)

if __name__ == '__main__':
    app.run(debug=True) 