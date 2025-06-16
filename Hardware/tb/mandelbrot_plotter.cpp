#include "VmandelbrotCore.h"
#include "verilated.h"
#include <iostream>
#include <fstream>

#define Q8_24(x) ((int32_t)((x) * 16777216.0))

const int WIDTH = 1920;
const int HEIGHT = 1080;
const int MAX_ITER = 100;
const int MAX_CYCLES = 10000;

int run_hw_point(VmandelbrotCore* top, int32_t x0_q8_24, int32_t y0_q8_24, int max_iter) {
    top->x0_i = x0_q8_24;
    top->y0_i = y0_q8_24;
    top->max_iter_i = max_iter;
    top->start_i = 1;

    top->clk_i = 0;
    top->eval();

    top->clk_i = 1;
    top->eval();

    top->start_i = 0;

    int cycles = 0;
    while (!top->done_o && cycles < MAX_CYCLES) {
        top->clk_i = !top->clk_i;
        top->eval();
        cycles++;
    }

    if (!top->done_o) {
        std::cerr << "ERROR: Timeout at x=" << x0_q8_24 << ", y=" << y0_q8_24 << std::endl;
        return -1;
    }

    return top->iter_o;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    VmandelbrotCore* top = new VmandelbrotCore;

    // Reset sequence
    top->rst_i = 1;
    top->clk_i = 0;
    top->start_i = 0;
    top->eval();

    for (int i = 0; i < 10; ++i) {
        top->clk_i = !top->clk_i;
        top->eval();
    }
    top->rst_i = 0;

    const double xmin = -2.0, xmax = 1.0;
    const double ymin = -1.5, ymax = 1.5;

    std::ofstream outfile("mandelbrot_pixels.csv");
    if (!outfile.is_open()) {
        std::cerr << "ERROR: Could not open output file\n";
        return 1;
    }
    outfile << "x,y,iter\n";

    for (int y = 0; y < HEIGHT; ++y) {
        for (int x = 0; x < WIDTH; ++x) {
            double fx = xmin + x * (xmax - xmin) / WIDTH;
            double fy = ymin + y * (ymax - ymin) / HEIGHT;
            int32_t x_q8_24 = Q8_24(fx);
            int32_t y_q8_24 = Q8_24(fy);

            int iter = run_hw_point(top, x_q8_24, y_q8_24, MAX_ITER);
            if (iter == -1) {
                delete top;
                return -1;
            }

            outfile << fx << "," << fy << "," << iter << "\n";
        }
    }

    outfile.close();
    delete top;
    std::cout << "Done. Output saved to mandelbrot_pixels.csv\n";
    return 0;
}
