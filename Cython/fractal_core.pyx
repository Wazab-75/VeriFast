# fractal_core.pyx

import numpy as np
cimport numpy as np

# Mandelbrot computation
def mandelbrot_cython(int width, int height, int max_iter, double cx, double cy, double zoom):
    cdef:
        double scale_x = 3.5 / zoom
        double scale_y = 2.0 / zoom
        double xmin = cx - scale_x / 2
        double ymin = cy - scale_y / 2
        double xmax = cx + scale_x / 2
        double ymax = cy + scale_y / 2
        np.ndarray[np.uint8_t, ndim=2] img = np.zeros((height, width), dtype=np.uint8)
        double x, y, zx, zy, zx2, zy2, tmp
        int i, j, n

    for i in range(height):
        for j in range(width):
            x = xmin + (xmax - xmin) * j / (width - 1)
            y = ymin + (ymax - ymin) * i / (height - 1)
            zx = 0.0
            zy = 0.0
            zx2 = zy2 = 0.0
            n = 0

            while zx2 + zy2 <= 4.0 and n < max_iter:
                tmp = zx2 - zy2 + x
                zy = 2.0 * zx * zy + y
                zx = tmp
                zx2 = zx * zx
                zy2 = zy * zy
                n += 1

            img[i, j] = 255 * n // max_iter

    return img

# Julia computation
def julia_cython(int width, int height, int max_iter, double zx, double zy, double zoom, double c_real, double c_imag):
    cdef:
        double scale_x = 3.5 / zoom
        double scale_y = 2.0 / zoom
        double xmin = zx - scale_x / 2
        double ymin = zy - scale_y / 2
        double xmax = zx + scale_x / 2
        double ymax = zy + scale_y / 2
        np.ndarray[np.uint8_t, ndim=2] img = np.zeros((height, width), dtype=np.uint8)
        double x, y, zx0, zy0, zx2, zy2, tmp
        int i, j, n

    for i in range(height):
        for j in range(width):
            zx0 = xmin + (xmax - xmin) * j / (width - 1)
            zy0 = ymin + (ymax - ymin) * i / (height - 1)
            zx2 = zx0 * zx0
            zy2 = zy0 * zy0
            n = 0

            while zx2 + zy2 <= 4.0 and n < max_iter:
                tmp = zx2 - zy2 + c_real
                zy0 = 2.0 * zx0 * zy0 + c_imag
                zx0 = tmp
                zx2 = zx0 * zx0
                zy2 = zy0 * zy0
                n += 1

            img[i, j] = 255 * n // max_iter

    return img
