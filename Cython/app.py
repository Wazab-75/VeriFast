from flask import Flask, render_template, request, jsonify, send_file
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import io
import time
import socket
import base64
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
performance_log = []  # Track performance of renders

# FPGA server configuration
FPGA_SERVER_URL = "https://f65b-146-179-86-172.ngrok-free.app"  # FPGA server ngrok URL
TIMEOUT = 5  # Timeout in seconds

# Configure session with connection pooling and retries
session = requests.Session()
retries = Retry(
    total=3,
    backoff_factor=0.1,
    status_forcelist=[500, 502, 503, 504]
)
adapter = HTTPAdapter(
    max_retries=retries,
    pool_connections=100,
    pool_maxsize=100
)
session.mount('https://', adapter)
session.mount('http://', adapter)

# Cache for server status
server_status_cache = {
    'last_check': 0,
    'is_available': False,
    'cache_duration': 5  # seconds
}

def check_fpga_server():
    """Check if FPGA server is reachable with caching"""
    current_time = time.time()
    
    # Return cached result if still valid
    if current_time - server_status_cache['last_check'] < server_status_cache['cache_duration']:
        return server_status_cache['is_available']
    
    try:
        # Use session for connection pooling
        response = session.get(f"{FPGA_SERVER_URL}/", timeout=1)
        is_available = response.status_code == 200
        
        # Update cache
        server_status_cache['last_check'] = current_time
        server_status_cache['is_available'] = is_available
        
        return is_available
    except:
        server_status_cache['last_check'] = current_time
        server_status_cache['is_available'] = False
        return False

@app.route('/')
def index():
    """Render the main page with FPGA availability status"""
    fpga_available = check_fpga_server()
    return render_template('index.html', fpga_available=fpga_available)

@app.route('/generate', methods=['POST'])
def generate_mandelbrot():
    """Generate a Mandelbrot fractal image"""
    try:
        if not check_fpga_server():
            return "FPGA server is not reachable. Please check if it's running and the IP address is correct.", 503

        data = request.json
        if not data:
            return "No data provided", 400

        # Prepare request parameters
        version = data.get('version', 'software')
        width = data.get('width', 640)
        height = data.get('height', 480)
        zoom = data.get('zoom', 1.0)
        center_x = data.get('center_x', -0.5)
        center_y = data.get('center_y', 0.0)

        # Calculate view coordinates
        scale_x = 4.0 / zoom
        scale_y = 3.0 / zoom
        top_x = center_x - scale_x/2
        top_y = center_y + scale_y/2

        request_data = {
            "version": version,
            "width": width,
            "height": height,
            "max_iter": data.get('max_iter', 300),
            "zoom": zoom,
            "top_x": top_x,
            "top_y": top_y,
            "cmap": data.get('cmap', 'hot'),
        }

        # Send request to FPGA server
        request_start = time.time()
        logger.info(f"Starting {version} Mandelbrot generation request")
        
        # Use session for connection pooling
        response = session.post(
            f"{FPGA_SERVER_URL}/generate", 
            json=request_data,
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            generate_end = time.time()
            generate_time = generate_end - request_start
            logger.info(f"Generate request completed in {generate_time:.3f}s")
            
            # Parse response data
            response_data = response.json()
            computation_time = float(response_data.get('computation_time', 0))
            
            # Get image data based on version
            if version == 'hardware':
                logger.info("Fetching hardware image...")
                img_start = time.time()
                img_response = session.get(f"{FPGA_SERVER_URL}/debug_hw_frame", timeout=TIMEOUT)
                img_time = time.time() - img_start
                logger.info(f"Hardware image fetch completed in {img_time:.3f}s")
                
                if img_response.status_code != 200:
                    return "Failed to get hardware image", 500
                img_byte_arr = io.BytesIO(img_response.content)
            else:
                image_data = base64.b64decode(response_data['image'])
                img_byte_arr = io.BytesIO(image_data)
            
            request_end = time.time()
            total_time = request_end - request_start
            request_delay = total_time - computation_time
            
            # Log detailed performance metrics
            performance_log.append({
                'type': 'mandelbrot',
                'version': version,
                'resolution': f"{width}x{height}",
                'computation_time': computation_time,
                'generate_time': round(generate_time, 3),
                'image_fetch_time': round(img_time if version == 'hardware' else 0, 3),
                'request_delay': round(request_delay, 3),
                'total_time': round(total_time, 3)
            })
            
            # Return image with detailed timing headers
            flask_response = send_file(img_byte_arr, mimetype='image/png')
            flask_response.headers['X-Computation-Time'] = str(computation_time)
            flask_response.headers['X-Generate-Time'] = str(round(generate_time, 3))
            if version == 'hardware':
                flask_response.headers['X-Image-Fetch-Time'] = str(round(img_time, 3))
            flask_response.headers['X-Request-Delay'] = str(round(request_delay, 3))
            flask_response.headers['X-Total-Time'] = str(round(total_time, 3))
            return flask_response
        else:
            return f"Error from FPGA server: {response.text}", response.status_code
            
    except requests.exceptions.Timeout:
        logger.error("Request to FPGA server timed out")
        return "Request to FPGA server timed out. Please try again.", 503
    except requests.exceptions.ConnectionError:
        logger.error("Could not connect to FPGA server")
        return "Could not connect to FPGA server. Please check if it's running.", 503
    except Exception as e:
        logger.error(f"Error generating Mandelbrot: {e}")
        return str(e), 500

@app.route('/generate_julia', methods=['POST'])
def generate_julia():
    """Generate a Julia fractal image"""
    try:
        if not check_fpga_server():
            return "FPGA server is not reachable. Please check if it's running and the IP address is correct.", 503

        data = request.json
        if not data:
            return "No data provided", 400

        # Prepare request parameters
        version = data.get('version', 'software')
        width = data.get('width', 320)
        height = data.get('height', 240)
        
        request_data = {
            "version": version,
            "width": width,
            "height": height,
            "max_iter": data.get('max_iter', 300),
            "zoom": data.get('zoom', 1.0),
            "center_x": data.get('center_x', -0.7),
            "center_y": data.get('center_y', 0.0),
            "cmap": data.get('cmap', 'hot')
        }

        # Send request to FPGA server
        request_start = time.time()
        logger.info(f"Starting {version} Julia generation request")
        
        # Use session for connection pooling
        response = session.post(
            f"{FPGA_SERVER_URL}/generate_julia", 
            json=request_data,
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            generate_end = time.time()
            generate_time = generate_end - request_start
            logger.info(f"Generate request completed in {generate_time:.3f}s")
            
            # Parse response data
            response_data = response.json()
            computation_time = float(response_data.get('computation_time', 0))
            
            # Get image data based on version
            if version == 'hardware':
                logger.info("Fetching hardware image...")
                img_start = time.time()
                img_response = session.get(f"{FPGA_SERVER_URL}/debug_hw_frame", timeout=TIMEOUT)
                img_time = time.time() - img_start
                logger.info(f"Hardware image fetch completed in {img_time:.3f}s")
                
                if img_response.status_code != 200:
                    return "Failed to get hardware image", 500
                img_byte_arr = io.BytesIO(img_response.content)
            else:
                image_data = base64.b64decode(response_data['image'])
                img_byte_arr = io.BytesIO(image_data)
            
            request_end = time.time()
            total_time = request_end - request_start
            request_delay = total_time - computation_time
            
            # Log detailed performance metrics
            performance_log.append({
                'type': 'julia',
                'version': version,
                'resolution': f"{width}x{height}",
                'computation_time': computation_time,
                'generate_time': round(generate_time, 3),
                'image_fetch_time': round(img_time if version == 'hardware' else 0, 3),
                'request_delay': round(request_delay, 3),
                'total_time': round(total_time, 3)
            })
            
            # Return image with detailed timing headers
            flask_response = send_file(img_byte_arr, mimetype='image/png')
            flask_response.headers['X-Computation-Time'] = str(computation_time)
            flask_response.headers['X-Generate-Time'] = str(round(generate_time, 3))
            if version == 'hardware':
                flask_response.headers['X-Image-Fetch-Time'] = str(round(img_time, 3))
            flask_response.headers['X-Request-Delay'] = str(round(request_delay, 3))
            flask_response.headers['X-Total-Time'] = str(round(total_time, 3))
            return flask_response
        else:
            return f"Error from FPGA server: {response.text}", response.status_code
            
    except requests.exceptions.Timeout:
        logger.error("Request to FPGA server timed out")
        return "Request to FPGA server timed out. Please try again.", 503
    except requests.exceptions.ConnectionError:
        logger.error("Could not connect to FPGA server")
        return "Could not connect to FPGA server. Please check if it's running.", 503
    except Exception as e:
        logger.error(f"Error generating Julia: {e}")
        return str(e), 500

@app.route('/performance')
def performance():
    """Return performance metrics for all renders"""
    return jsonify(performance_log)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)  # Set debug=False for production