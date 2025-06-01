#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VjuliaCore.h"
#include <iostream>
#include <fstream>  // Added for file operations
#include <cmath>

#define Q8_24(x) ((int32_t)std::round((x) * (1<<24)))  // Improved version with proper rounding
#define MAX_ITER 1000
#define MAX_CYCLES 10000

#define RESET "\033[0m"
#define RED "\033[31m"
#define GREEN "\033[32m"

// Fixed complex constant for the Julia set
const double C_RE = -0.8;
const double C_IM = 0.156;

int julia_ref(double x0, double y0, int max_iter) {
    double x = x0, y = y0;
    int iter = 0;
    while (x * x + y * y <= 4.0 && iter < max_iter) {
        double xtemp = x * x - y * y + C_RE;
        y = 2 * x * y + C_IM;
        x = xtemp;
        iter++;
    }
    return iter;
}

int run_hw_point(VjuliaCore* top, int32_t z0_x, int32_t z0_y, int32_t c_x, int32_t c_y, int max_iter, VerilatedVcdC* tfp = nullptr, vluint64_t* time = nullptr) {
    top->clk_i = 0;
    top->rst_i = 1;
    top->start_i = 0;
    top->eval(); if (tfp) tfp->dump((*time)++);
    top->clk_i = 1;
    top->eval(); if (tfp) tfp->dump((*time)++);
    top->rst_i = 0;

    // Apply inputs
    top->zx_i = z0_x;
    top->zy_i = z0_y;
    top->cx_i = c_x;
    top->cy_i = c_y;
    top->max_iter_i = max_iter;
    top->start_i = 1;

    top->clk_i = 0;
    top->eval(); if (tfp) tfp->dump((*time)++);
    top->clk_i = 1;
    top->eval(); if (tfp) tfp->dump((*time)++);
    top->start_i = 0;

    int cycles = 0;
    while (!top->done_o && cycles < MAX_CYCLES) {
        top->clk_i = !top->clk_i;
        top->eval();
        if (tfp) tfp->dump((*time)++);
        cycles++;
    }

    if (!top->done_o) {
        std::cerr << RED << "ERROR: Timeout at z0=(" << z0_x << ", " << z0_y << ")" << RESET << std::endl;
        return -1;
    }

    return top->iter_o;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    VjuliaCore* top = new VjuliaCore;

    vluint64_t sim_time = 0;
    VerilatedVcdC* tfp = nullptr;  // Set to non-null to enable waveform tracing

    // Full Julia set region
    const double full_xmin = -1.5, full_xmax = 1.5;
    const double full_ymin = -1.5, full_ymax = 1.5;
    
    // Calculate the 16:9 crop region
    const double full_width = full_xmax - full_xmin;
    const double full_height = full_ymin - full_ymax;
    const double target_ratio = 1920.0 / 1080.0;  // 16:9
    
    double crop_width, crop_height;
    if (full_width / full_height > target_ratio) {
        // If full region is wider than 16:9, crop width
        crop_height = full_height;
        crop_width = crop_height * target_ratio;
    } else {
        // If full region is taller than 16:9, crop height
        crop_width = full_width;
        crop_height = crop_width / target_ratio;
    }
    
    // Center the crop
    const double xmin = (full_xmin + full_xmax - crop_width) / 2;
    const double xmax = xmin + crop_width;
    const double ymin = (full_ymin + full_ymax + crop_height) / 2;  // Note: y is inverted
    const double ymax = ymin - crop_height;
    
    const int WIDTH = 1920;
    const int HEIGHT = 1080;

    std::ofstream outfile("julia_pixels.csv");
    if (!outfile.is_open()) {
        std::cerr << "ERROR: Could not open output file\n";
        return 1;
    }
    outfile << "x,y,iter\n";

    int32_t c_x_q8_24 = Q8_24(C_RE);
    int32_t c_y_q8_24 = Q8_24(C_IM);
    int error_count = 0;

    for (int j = 0; j < HEIGHT; ++j) {
        double y = ymin + j * (ymax - ymin) / (HEIGHT - 1);
        for (int i = 0; i < WIDTH; ++i) {
            double x = xmin + i * (xmax - xmin) / (WIDTH - 1);
            int ref = julia_ref(x, y, MAX_ITER);
            int32_t z0_x = Q8_24(x);
            int32_t z0_y = Q8_24(y);
            int dut = run_hw_point(top, z0_x, z0_y, c_x_q8_24, c_y_q8_24, MAX_ITER, tfp, &sim_time);

            if (std::abs(dut - ref) > 2) {
                std::cout << RED << "Mismatch at (" << x << ", " << y << "): " << "HW = " << dut << ", REF = " << ref << RESET << std::endl;
                error_count++;
            }

            outfile << x << "," << y << "," << dut << "\n";
        }
    }

    if (error_count == 0) {
        std::cout << GREEN << "All test points passed." << RESET << std::endl;
    } else {
        std::cout << RED << error_count << " mismatches found " << (WIDTH*HEIGHT - error_count)*100.0/(WIDTH*HEIGHT) << "% passed" << RESET << std::endl;
    }

    outfile.close();
    delete top;
    std::cout << "Done. Output saved to julia_pixels.csv\n";
    return 0;
}
