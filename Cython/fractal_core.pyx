# fractal_core.pyx

import numpy as np
cimport numpy as np
from cython.parallel import prange
cimport cython

# Type definitions
ctypedef np.uint8_t DTYPE_t

# Compiler optimizations
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def mandelbrot_cython(int width, int height, int max_iter, double cx, double cy, double zoom):
    """
    Generate Mandelbrot fractal image using Cython with parallel processing.
    
    Parameters:
    - width, height: Image dimensions
    - max_iter: Maximum iterations
    - cx, cy: Center coordinates
    - zoom: Zoom level
    """
    cdef:
        # Calculate bounds
        double scale = 3.5 / zoom
        double xmin = cx - scale / 2
        double ymin = cy - scale * height / width / 2
        double dx = scale / width
        double dy = scale * height / width / height
        
        # Image array
        np.ndarray[DTYPE_t, ndim=2] img = np.zeros((height, width), dtype=np.uint8)
        
        # Loop variables
        double x, y, zx, zy, zx2, zy2
        int i, j, n

    # Parallel processing over rows
    for i in prange(height, nogil=True):
        y = ymin + i * dy
        
        for j in range(width):
            x = xmin + j * dx
            
            # Mandelbrot iteration: z = z^2 + c
            zx = zy = 0.0
            
            for n in range(max_iter):
                zx2 = zx * zx
                zy2 = zy * zy
                
                # Check if escaped
                if zx2 + zy2 > 4.0:
                    break
                
                # z = z^2 + c
                zy = 2.0 * zx * zy + y
                zx = zx2 - zy2 + x
            
            # Color based on iteration count
            img[i, j] = <DTYPE_t>(255 * n / max_iter) if n < max_iter else 0

    return img


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def julia_cython(int width, int height, int max_iter, double zx, double zy, double zoom, double c_real, double c_imag):
    """
    Generate Julia set fractal image.
    
    Parameters:
    - width, height: Image dimensions
    - max_iter: Maximum iterations
    - zx, zy: Center of view
    - zoom: Zoom level
    - c_real, c_imag: Julia constant
    """
    cdef:
        # Calculate bounds
        double scale = 3.5 / zoom
        double xmin = zx - scale / 2
        double ymin = zy - scale * height / width / 2
        double dx = scale / width
        double dy = scale * height / width / height
        
        # Image array
        np.ndarray[DTYPE_t, ndim=2] img = np.zeros((height, width), dtype=np.uint8)
        
        # Loop variables
        double x, y, x2, y2, temp
        int i, j, n

    # Parallel processing
    for i in prange(height, nogil=True):
        for j in range(width):
            # Starting point
            x = xmin + j * dx
            y = ymin + i * dy
            
            # Julia iteration: z = z^2 + c
            for n in range(max_iter):
                x2 = x * x
                y2 = y * y
                
                # Check if escaped
                if x2 + y2 > 4.0:
                    break
                
                # z = z^2 + c
                temp = x2 - y2 + c_real
                y = 2.0 * x * y + c_imag
                x = temp
            
            # Color based on iteration count
            img[i, j] = <DTYPE_t>(255 * n / max_iter) if n < max_iter else 0

    return img
