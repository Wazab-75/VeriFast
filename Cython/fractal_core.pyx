# fractal_core.pyx

import numpy as np
cimport numpy as np
from cython.parallel import prange
cimport cython

# Type definitions
ctypedef np.uint8_t DTYPE_t
ctypedef np.int32_t FIXED_t

# Fixed point scaling factor (2^16 for 16-bit precision)
DEF SCALE_FACTOR = 65536
DEF SCALE_FACTOR_F = 65536.0

# Compiler optimizations
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def mandelbrot_cython(int width, int height, int max_iter, double cx, double cy, double zoom):
    """
    Generate Mandelbrot fractal image using Cython with parallel processing and fixed-point arithmetic.
    
    Parameters:
    - width, height: Image dimensions
    - max_iter: Maximum iterations
    - cx, cy: Center coordinates
    - zoom: Zoom level
    """
    cdef:
        # Calculate bounds (converted to fixed point)
        double scale = 3.5 / zoom
        double xmin = cx - scale / 2
        double ymin = cy - scale * height / width / 2
        double dx = scale / width
        double dy = scale * height / width / height
        
        # Image array with memory view
        cdef DTYPE_t[:, :] img = np.zeros((height, width), dtype=np.uint8)
        
        # Loop variables
        FIXED_t x, y, zx, zy, zx2, zy2
        int i, j, n
        double temp_x, temp_y

    # Parallel processing over rows
    for i in prange(height, nogil=True):
        temp_y = ymin + i * dy
        y = <FIXED_t>(temp_y * SCALE_FACTOR)
        
        for j in range(width):
            temp_x = xmin + j * dx
            x = <FIXED_t>(temp_x * SCALE_FACTOR)
            
            # Mandelbrot iteration: z = z^2 + c
            zx = zy = 0
            
            for n in range(max_iter):
                # Fixed point multiplication (right shift by 16 bits)
                zx2 = (zx * zx) >> 16
                zy2 = (zy * zy) >> 16
                
                # Check if escaped (scaled by SCALE_FACTOR)
                if (zx2 + zy2) > (4 * SCALE_FACTOR):
                    break
                
                # z = z^2 + c (fixed point arithmetic)
                zy = ((2 * zx * zy) >> 16) + y
                zx = zx2 - zy2 + x
            
            # Color based on iteration count
            img[i, j] = <DTYPE_t>(255 * n / max_iter) if n < max_iter else 0

    return np.asarray(img)


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def julia_cython(int width, int height, int max_iter, double zx, double zy, double zoom, double c_real, double c_imag):
    """
    Generate Julia set fractal image using fixed-point arithmetic.
    
    Parameters:
    - width, height: Image dimensions
    - max_iter: Maximum iterations
    - zx, zy: Center of view
    - zoom: Zoom level
    - c_real, c_imag: Julia constant
    """
    cdef:
        # Calculate bounds (converted to fixed point)
        double scale = 3.5 / zoom
        double xmin = zx - scale / 2
        double ymin = zy - scale * height / width / 2
        double dx = scale / width
        double dy = scale * height / width / height
        
        # Image array with memory view
        cdef DTYPE_t[:, :] img = np.zeros((height, width), dtype=np.uint8)
        
        # Loop variables
        FIXED_t x, y, x2, y2, temp
        int i, j, n
        double temp_x, temp_y
        FIXED_t c_real_fixed = <FIXED_t>(c_real * SCALE_FACTOR)
        FIXED_t c_imag_fixed = <FIXED_t>(c_imag * SCALE_FACTOR)

    # Parallel processing
    for i in prange(height, nogil=True):
        temp_y = ymin + i * dy
        y = <FIXED_t>(temp_y * SCALE_FACTOR)
        
        for j in range(width):
            temp_x = xmin + j * dx
            x = <FIXED_t>(temp_x * SCALE_FACTOR)
            
            # Julia iteration: z = z^2 + c
            for n in range(max_iter):
                # Fixed point multiplication
                x2 = (x * x) >> 16
                y2 = (y * y) >> 16
                
                # Check if escaped
                if (x2 + y2) > (4 * SCALE_FACTOR):
                    break
                
                # z = z^2 + c (fixed point arithmetic)
                temp = x2 - y2 + c_real_fixed
                y = ((2 * x * y) >> 16) + c_imag_fixed
                x = temp
            
            # Color based on iteration count
            img[i, j] = <DTYPE_t>(255 * n / max_iter) if n < max_iter else 0

    return np.asarray(img)
