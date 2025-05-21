from flask import Flask, request, render_template, send_file, jsonify
from mandelbrot_generator import generate_image
from julia_generator import generate_julia_image

app = Flask(__name__)
performance_log = []  # Track performance of Mandelbrot/Julia renders

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/generate', methods=['POST'])
def generate_mandelbrot():
    try:
        data = request.json
        if not data:
            return "No data provided", 400

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
            'resolution': f'{width}x{height}',
            'time': round(elapsed, 3)
        })

        return send_file(buf, mimetype='image/png')

    except Exception as e:
        print("Error generating Mandelbrot:", e)
        return str(e), 500


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
