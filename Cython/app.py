from flask import Flask, render_template, request, jsonify, send_file
import requests
import io
from PIL import Image
import socket

app = Flask(__name__)
performance_log = []  # Track performance of renders

# FPGA server configuration
FPGA_SERVER_URL = "http://192.168.137.50:5002"# FPGA server IP address
TIMEOUT = 5  # Timeout in seconds

def check_fpga_server():
    """Check if FPGA server is reachable"""
    try:
        # Try to establish a TCP connection
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT)
        result = sock.connect_ex(('192.168.137.50', 5002))
        sock.close()
        return result == 0
    except:
        return False

@app.route('/')
def index():
    fpga_available = check_fpga_server()
    return render_template('index.html', fpga_available=fpga_available)

@app.route('/generate', methods=['POST'])
def generate_mandelbrot():
    try:
        # Check if FPGA server is available
        if not check_fpga_server():
            return "FPGA server is not reachable. Please check if it's running and the IP address is correct.", 503

        # Get parameters from request
        data = request.json
        if not data:
            return "No data provided", 400

        # Prepare request data with all parameters
        request_data = {
            "version": data.get('version', 'software'),
            "width": data.get('width', 640),
            "height": data.get('height', 480),
            "max_iter": data.get('max_iter', 300),
            "zoom": data.get('zoom', 1.0),
            "center_x": data.get('center_x', -0.7),
            "center_y": data.get('center_y', 0.0),
            "cmap": data.get('cmap', 'hot')
        }

        # Forward the request to the FPGA server with timeout
        response = requests.post(
            f"{FPGA_SERVER_URL}/generate", 
            json=request_data,
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            # Get the image data from the FPGA server
            img_data = response.content
            img_byte_arr = io.BytesIO(img_data)
            
            # Log the performance
            performance_log.append({
                'type': 'mandelbrot',
                'version': request_data['version'],
                'resolution': f"{request_data['width']}x{request_data['height']}",
                'time': 0  # FPGA is instant
            })
            
            return send_file(img_byte_arr, mimetype='image/png')
        else:
            return f"Error from FPGA server: {response.text}", response.status_code
            
    except requests.exceptions.Timeout:
        print("Request to FPGA server timed out")
        return "Request to FPGA server timed out. Please try again.", 503
    except requests.exceptions.ConnectionError:
        print("Could not connect to FPGA server")
        return "Could not connect to FPGA server. Please check if it's running.", 503
    except Exception as e:
        print(f"Error generating Mandelbrot: {e}")
        return str(e), 500

@app.route('/generate_julia', methods=['POST'])
def generate_julia():
    try:
        # Check if FPGA server is available
        if not check_fpga_server():
            return "FPGA server is not reachable. Please check if it's running and the IP address is correct.", 503

        # Get parameters from request
        data = request.json
        if not data:
            return "No data provided", 400

        # Prepare request data with all parameters
        request_data = {
            "version": data.get('version', 'software'),
            "width": data.get('width', 640),
            "height": data.get('height', 480),
            "max_iter": data.get('max_iter', 300),
            "zoom": data.get('zoom', 1.0),
            "center_x": data.get('center_x', -0.7),
            "center_y": data.get('center_y', 0.0),
            "cmap": data.get('cmap', 'hot')
        }

        # Forward the request to the FPGA server with timeout
        response = requests.post(
            f"{FPGA_SERVER_URL}/generate_julia", 
            json=request_data,
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            # Get the image data from the FPGA server
            img_data = response.content
            img_byte_arr = io.BytesIO(img_data)
            
            # Log the performance
            performance_log.append({
                'type': 'julia',
                'version': request_data['version'],
                'resolution': f"{request_data['width']}x{request_data['height']}",
                'time': 0  # FPGA is instant
            })
            
            return send_file(img_byte_arr, mimetype='image/png')
        else:
            return f"Error from FPGA server: {response.text}", response.status_code
            
    except requests.exceptions.Timeout:
        print("Request to FPGA server timed out")
        return "Request to FPGA server timed out. Please try again.", 503
    except requests.exceptions.ConnectionError:
        print("Could not connect to FPGA server")
        return "Could not connect to FPGA server. Please check if it's running.", 503
    except Exception as e:
        print(f"Error generating Julia: {e}")
        return str(e), 500

@app.route('/performance')
def performance():
    return jsonify(performance_log)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)  # Using port 5001 to avoid conflict with FPGA server
