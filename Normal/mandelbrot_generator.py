import numpy as np
import matplotlib.pyplot as plt
import io
import time

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

def generate_image(width, height, max_iter, zoom, cx, cy, cmap='hot'):
    """
    Generate a Mandelbrot set image with the given parameters.
    Returns the image as a PNG file in memory.
    """
    start = time.time()
    img = mandelbrot(width, height, max_iter, cx, cy, zoom)
    elapsed = time.time() - start
    
    buf = io.BytesIO()
    plt.imsave(buf, img, cmap=cmap, format='png')
    buf.seek(0)
    
    return buf, elapsed 