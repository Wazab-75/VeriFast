from flask import Flask, request, render_template, send_file, jsonify
from mandelbrot_generator import generate_image

app = Flask(__name__)
performance_log = []  # Store (resolution, time) tuples

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

        # Generate the image
        buf, elapsed = generate_image(width, height, max_iter, zoom, cx, cy, cmap)
        performance_log.append({'resolution': f'{width}x{height}', 'time': round(elapsed, 3)})

        return send_file(buf, mimetype='image/png')

    except Exception as e:
        print(f"Error generating fractal: {str(e)}")
        return str(e), 500

@app.route('/performance')
def performance():
    return jsonify(performance_log)

if __name__ == '__main__':
    app.run(debug=True) 