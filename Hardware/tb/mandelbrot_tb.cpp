#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VmandelbrotCore.h"
#include <iostream>
#include <cmath>

#define Q8_24(x) ((int32_t)((x) * 16777216.0))
#define MAX_ITER 1000
#define MAX_CYCLES 10000

// ANSI colour codes for terminal output
#define RESET "\033[0m"
#define RED "\033[31m"
#define GREEN "\033[32m"

// Software reference implementation of Mandelbrot
int mandelbrot_ref(double x0, double y0, int max_iter) {
    double x = 0.0, y = 0.0;
    int iter = 0;
    while (x * x + y * y <= 4.0 && iter < max_iter) {
        double xtemp = x * x - y * y + x0;
        y = 2 * x * y + y0;
        x = xtemp;
        iter++;
    }
    return iter;
}

// Run one test point on the DUT and return iterations
int run_hw_point(VmandelbrotCore* top, int32_t x0_q8_24, int32_t y0_q8_24, int max_iter, VerilatedVcdC* tfp = nullptr, vluint64_t* time = nullptr) {
    top->clk_i = 0;
    top->rst_i = 1;
    top->start_i = 0;
    top->eval(); if (tfp) tfp->dump((*time)++);
    top->clk_i = 1;
    top->eval(); if (tfp) tfp->dump((*time)++);
    top->rst_i = 0;

    // Apply inputs
    top->x0_i = x0_q8_24;
    top->y0_i = y0_q8_24;
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
        std::cerr << RED << "ERROR: Timeout at x=" << x0_q8_24 << ", y=" << y0_q8_24 << RESET << std::endl;
        return -1;
    }

    return top->iter_o;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    VmandelbrotCore* top = new VmandelbrotCore;

    vluint64_t sim_time = 0;
    VerilatedVcdC* tfp = nullptr;  // Set to non-null to enable waveform tracing

    // Test region: real in [-2, 1], imag in [-1.5, 1.5]
    const double xmin = -2.0, xmax = 1.0;
    const double ymin = -1.5, ymax = 1.5;
    const int steps = 1000;  // Grid resolution

    int error_count = 0;

    for (int j = 0; j < steps; ++j) {
        double y = ymin + j * (ymax - ymin) / steps;
        for (int i = 0; i < steps; ++i) {
            double x = xmin + i * (xmax - xmin) / steps;
            int ref = mandelbrot_ref(x, y, MAX_ITER);
            int32_t x_q8_24 = Q8_24(x);
            int32_t y_q8_24 = Q8_24(y);
            int dut = run_hw_point(top, x_q8_24, y_q8_24, MAX_ITER, tfp, &sim_time);

            //if (std::abs(dut - ref) > 2) {
            if (dut != ref) {
                std::cout << RED << "Mismatch at (" << x << ", " << y << "): " << "HW = " << dut << ", REF = " << ref << RESET << std::endl;
                error_count++;
            } else {
                std::cout << GREEN << "Pass at (" << x << ", " << y << "): " << "Iterations = " << dut << RESET << std::endl;
            }
        }
    }

    if (error_count == 0) {
        std::cout << GREEN << "All test points passed." << RESET << std::endl;
    } else {
        std::cout << RED << error_count << " mismatches found " << (steps*steps - error_count)*100.0/(steps*steps) << "% passed" << RESET << std::endl;
    }

    delete top;
    return 0;
}