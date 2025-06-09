# fractal_core.pyx
# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True

import numpy as np
cimport numpy as np
cimport cython

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def mandelbrot_cython(int width, int height,
                      int max_iter,
                      double cx, double cy,
                      double zoom):
    cdef:
        double scale_x = 3.5 / zoom
        double scale_y = 2.0 / zoom
        double xmin = cx - 0.5 * scale_x
        double ymin = cy - 0.5 * scale_y
        double dx = scale_x / (width - 1)
        double dy = scale_y / (height - 1)
        np.ndarray[np.uint8_t, ndim=2] img = np.empty((height, width), dtype=np.uint8)
        np.uint8_t[:, :] view = img
        int i, j, n
        double x0, y0, zx, zy, zx2, zy2, tmp
        double bailout = 4.0
        double bailout2 = 2.0  # Early bailout threshold

    for i in range(height):
        y0 = ymin + dy * i
        for j in range(width):
            x0 = xmin + dx * j
            zx = 0.0
            zy = 0.0
            zx2 = 0.0
            zy2 = 0.0
            
            # escape-time loop with early bailout
            for n in range(max_iter):
                # Check early bailout condition
                if zx2 + zy2 > bailout2:
                    if zx2 + zy2 > bailout:
                        break
                
                # Compute next iteration
                zy = 2.0 * zx * zy + y0
                zx = zx2 - zy2 + x0
                
                # Update squares for next iteration
                zx2 = zx * zx
                zy2 = zy * zy
                
                # Final bailout check
                if zx2 + zy2 > bailout:
                    break
            
            view[i, j] = <np.uint8_t>((255 * n) // max_iter)
    return img


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def julia_cython(int width, int height,
                 int max_iter,
                 double zx0, double zy0,
                 double zoom,
                 double c_real, double c_imag):
    cdef:
        double scale_x = 3.5 / zoom
        double scale_y = 2.0 / zoom
        double xmin = zx0 - 0.5 * scale_x
        double ymin = zy0 - 0.5 * scale_y
        double dx = scale_x / (width - 1)
        double dy = scale_y / (height - 1)
        np.ndarray[np.uint8_t, ndim=2] img = np.empty((height, width), dtype=np.uint8)
        np.uint8_t[:, :] view = img
        int i, j, n
        double x, y, zx, zy, zx2, zy2, tmp
        double bailout = 4.0
        double bailout2 = 2.0  # Early bailout threshold

    for i in range(height):
        y = ymin + dy * i
        for j in range(width):
            x = xmin + dx * j
            zx = x
            zy = y
            zx2 = x * x
            zy2 = y * y
            
            # escape-time loop with early bailout
            for n in range(max_iter):
                # Check early bailout condition
                if zx2 + zy2 > bailout2:
                    if zx2 + zy2 > bailout:
                        break
                
                # Compute next iteration
                zy = 2.0 * zx * zy + c_imag
                zx = zx2 - zy2 + c_real
                
                # Update squares for next iteration
                zx2 = zx * zx
                zy2 = zy * zy
                
                # Final bailout check
                if zx2 + zy2 > bailout:
                    break
            
            view[i, j] = <np.uint8_t>((255 * n) // max_iter)
    return img
