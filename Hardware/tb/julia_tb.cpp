#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VjuliaCore.h"
#include <iostream>
#include <cmath>

#define Q8_24(x) ((int32_t)((x) * 16777216.0))
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
    VerilatedVcdC* tfp = nullptr;

    // Test region: real in [-1.5, 1.5], imag in [-1.5, 1.5]
    const double xmin = -1.5, xmax = 1.5;
    const double ymin = -1.5, ymax = 1.5;
    const int steps = 100;  // adjust for resolution

    int error_count = 0;
    int32_t c_x_q8_24 = Q8_24(C_RE);
    int32_t c_y_q8_24 = Q8_24(C_IM);

    for (int j = 0; j < steps; ++j) {
        double y = ymin + j * (ymax - ymin) / steps;
        for (int i = 0; i < steps; ++i) {
            double x = xmin + i * (xmax - xmin) / steps;
            int ref = julia_ref(x, y, MAX_ITER);
            int32_t z0_x = Q8_24(x);
            int32_t z0_y = Q8_24(y);
            int dut = run_hw_point(top, z0_x, z0_y, c_x_q8_24, c_y_q8_24, MAX_ITER, tfp, &sim_time);

            if (dut != ref) {
                std::cout << RED << "Mismatch at (" << x << ", " << y << "): HW = " << dut << ", REF = " << ref << RESET << std::endl;
                error_count++;
            } else {
                std::cout << GREEN << "Pass at (" << x << ", " << y << "): Iter = " << dut << RESET << std::endl;
            }
        }
    }

    if (error_count == 0) {
        std::cout << GREEN << "All test points passed." << RESET << std::endl;
    } else {
        std::cout << RED << error_count << " mismatches found. " << (steps * steps - error_count) * 100.0 / (steps * steps) << "% passed." << RESET << std::endl;
    }

    delete top;
    return 0;
}
