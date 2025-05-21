import io
import time
import matplotlib.pyplot as plt
from fractal_core import mandelbrot_cython

def generate_image(width, height, max_iter, zoom, cx, cy, cmap='hot'):
    start = time.time()
    img = mandelbrot_cython(width, height, max_iter, cx, cy, zoom)
    elapsed = time.time() - start

    buf = io.BytesIO()
    plt.imsave(buf, img, cmap=cmap, format='png')
    buf.seek(0)

    return buf, elapsed
