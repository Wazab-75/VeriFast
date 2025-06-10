// fractal_core.c
#include <stdint.h>
#include <stdlib.h>
#include <math.h>

void mandelbrot_c(
    uint8_t* img, int width, int height, int max_iter,
    double cx, double cy, double zoom
) {
    double scale = 3.5 / zoom;
    double xmin = cx - scale / 2.0;
    double ymin = cy - scale * height / width / 2.0;
    double dx = scale / width;
    double dy = scale * height / width / height;
    
    for (int i = 0; i < height; ++i) {
        double y = ymin + i * dy;
        for (int j = 0; j < width; ++j) {
            double x = xmin + j * dx;
            double zx = 0.0, zy = 0.0;
            int n;
            for (n = 0; n < max_iter; ++n) {
                double zx2 = zx * zx, zy2 = zy * zy;
                if (zx2 + zy2 > 4.0) break;
                double temp = zx2 - zy2 + x;
                zy = 2.0 * zx * zy + y;
                zx = temp;
            }
            img[i * width + j] = (n < max_iter) ? (uint8_t)(255 * n / max_iter) : 0;
        }
    }
}

void julia_c(
    uint8_t* img, int width, int height, int max_iter,
    double zx_center, double zy_center, double zoom, double c_real, double c_imag
) {
    double scale = 3.5 / zoom;
    double xmin = zx_center - scale / 2.0;
    double ymin = zy_center - scale * height / width / 2.0;
    double dx = scale / width;
    double dy = scale * height / width / height;
    
    for (int i = 0; i < height; ++i) {
        for (int j = 0; j < width; ++j) {
            double x = xmin + j * dx;
            double y = ymin + i * dy;
            int n;
            for (n = 0; n < max_iter; ++n) {
                double x2 = x * x, y2 = y * y;
                if (x2 + y2 > 4.0) break;
                double temp = x2 - y2 + c_real;
                y = 2.0 * x * y + c_imag;
                x = temp;
            }
            img[i * width + j] = (n < max_iter) ? (uint8_t)(255 * n / max_iter) : 0;
        }
    }
}
