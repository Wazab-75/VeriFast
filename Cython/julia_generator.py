import io
import time
import matplotlib.pyplot as plt
import numpy as np
import ctypes

# Load C shared library (adjust path if needed)
lib = ctypes.CDLL('./libfractal_core.so')

# Setup function signature for julia_c
lib.julia_c.argtypes = [
    ctypes.POINTER(ctypes.c_uint8),
    ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.c_double, ctypes.c_double, ctypes.c_double,
    ctypes.c_double, ctypes.c_double
]
lib.julia_c.restype = None

def julia_c(width, height, max_iter, zx, zy, zoom, c_real, c_imag):
    img = np.zeros((height, width), dtype=np.uint8)
    ptr = img.ctypes.data_as(ctypes.POINTER(ctypes.c_uint8))
    lib.julia_c(ptr, width, height, max_iter, zx, zy, zoom, c_real, c_imag)
    return img

def generate_julia_image(width, height, max_iter, zoom, zx, zy, c, cmap='hot'):
    start = time.time()
    img = julia_c(width, height, max_iter, zx, zy, zoom, c.real, c.imag)
    elapsed = time.time() - start

    buf = io.BytesIO()
    plt.imsave(buf, img, cmap=cmap, format='png')
    buf.seek(0)

    return buf, elapsed
