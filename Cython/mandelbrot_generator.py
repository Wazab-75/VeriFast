import io
import time
import matplotlib.pyplot as plt
import numpy as np
import ctypes

# Load C shared library (adjust path if needed)
lib = ctypes.CDLL('./libfractal_core.so')

# Setup function signature for mandelbrot_c
lib.mandelbrot_c.argtypes = [
    ctypes.POINTER(ctypes.c_uint8),
    ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.c_double, ctypes.c_double, ctypes.c_double
]
lib.mandelbrot_c.restype = None

def mandelbrot_c(width, height, max_iter, cx, cy, zoom):
    img = np.zeros((height, width), dtype=np.uint8)
    ptr = img.ctypes.data_as(ctypes.POINTER(ctypes.c_uint8))
    lib.mandelbrot_c(ptr, width, height, max_iter, cx, cy, zoom)
    return img

def generate_image(width, height, max_iter, zoom, cx, cy, cmap='hot'):
    start = time.time()
    img = mandelbrot_c(width, height, max_iter, cx, cy, zoom)
    elapsed = time.time() - start

    buf = io.BytesIO()
    plt.imsave(buf, img, cmap=cmap, format='png')
    buf.seek(0)

    return buf, elapsed
