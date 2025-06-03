# fractal_core_fast.pyx

import numpy as np
cimport numpy as np
cimport cython
# from cython.parallel import prange  # Not used for now

# -------------------------------------------------------------------
# Mandelbrot
# -------------------------------------------------------------------

@cython.boundscheck(False)
@cython.wraparound(False)
def mandelbrot_cython(int width,
                      int height,
                      int max_iter,
                      double cx,
                      double cy,
                      double zoom):
    """
    Produce an 8-bit grayscale Mandelbrot escape-time image of size (height×width),
    centered at (cx, cy) with zoom factor `zoom`.
    - Skips any point inside the main cardioid or period-2 bulb.
    """

    cdef double scale_x = 3.5 / zoom
    cdef double scale_y = 2.0 / zoom
    cdef double xmin = cx - scale_x / 2.0
    cdef double ymin = cy - scale_y / 2.0

    # Precompute per-pixel increments
    cdef double xstep = scale_x / (width - 1)
    cdef double ystep = scale_y / (height - 1)

    # Allocate output array and grab a C-level view
    cdef np.ndarray[np.uint8_t, ndim=2] img = np.zeros((height, width), dtype=np.uint8)
    cdef unsigned char[:, :] view = img

    cdef int i, j, n
    cdef double x0, y0, zx, zy, zx2, zy2, tmp
    cdef double x_minus_0_25, y_sq, q

    for i in range(height):
        y0 = ymin + i * ystep
        for j in range(width):
            x0 = xmin + j * xstep
            x_minus_0_25 = x0 - 0.25
            y_sq = y0 * y0
            q = x_minus_0_25 * x_minus_0_25 + y_sq
            if q * (q + x_minus_0_25) <= 0.25 * y_sq:
                view[i, j] = 255
            elif (x0 + 1.0) * (x0 + 1.0) + y_sq <= 0.0625:
                view[i, j] = 255
            else:
                zx = 0.0
                zy = 0.0
                zx2 = 0.0
                zy2 = 0.0
                n = 0
                while zx2 + zy2 <= 4.0 and n < max_iter:
                    tmp = zx2 - zy2 + x0
                    zy = 2.0 * zx * zy + y0
                    zx = tmp
                    zx2 = zx * zx
                    zy2 = zy * zy
                    n += 1
                view[i, j] = <unsigned char>(255 * n // max_iter)
    return img

# -------------------------------------------------------------------
# Julia
# -------------------------------------------------------------------

@cython.boundscheck(False)
@cython.wraparound(False)
def julia_cython(int width,
                 int height,
                 int max_iter,
                 double zx_center,
                 double zy_center,
                 double zoom,
                 double c_real,
                 double c_imag):
    """
    Produce an 8-bit grayscale Julia escape-time image of size (height×width),
    sampling initial z across a rectangle centered at (zx_center, zy_center) with
    zoom factor `zoom`. The constant is (c_real, c_imag).
    """

    cdef double scale_x = 3.5 / zoom
    cdef double scale_y = 2.0 / zoom
    cdef double xmin = zx_center - scale_x / 2.0
    cdef double ymin = zy_center - scale_y / 2.0

    # Precompute per-pixel increments
    cdef double xstep = scale_x / (width - 1)
    cdef double ystep = scale_y / (height - 1)

    # Allocate output and grab C-view
    cdef np.ndarray[np.uint8_t, ndim=2] img = np.zeros((height, width), dtype=np.uint8)
    cdef unsigned char[:, :] view = img

    cdef int i, j, n
    cdef double zx0, zy0, zx2, zy2, tmp
    cdef double x0, y0

    for i in range(height):
        y0 = ymin + i * ystep
        for j in range(width):
            zx0 = xmin + j * xstep
            zy0 = y0
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
            view[i, j] = <unsigned char>(255 * n // max_iter)
    return img
