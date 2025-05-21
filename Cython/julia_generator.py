import io
import time
import matplotlib.pyplot as plt
from fractal_core import julia_cython

def generate_julia_image(width, height, max_iter, zoom, zx, zy, c, cmap='hot'):
    start = time.time()
    img = julia_cython(width, height, max_iter, zx, zy, zoom, c.real, c.imag)
    elapsed = time.time() - start

    buf = io.BytesIO()
    plt.imsave(buf, img, cmap=cmap, format='png')
    buf.seek(0)

    return buf, elapsed
