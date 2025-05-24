#!/bin/bash
rm -rf obj_dir

# Exit if any command fails
set -e

# Variables
TOP_MODULE="fractalCores"
MANDELBROT_CORE="mandelbrotCore"
QMULT_MODULE="qMult_sc"
CPP_FILE="parallel_test.cpp"

# Run Verilator
verilator --sv -Wall --cc --trace ../rtl/${TOP_MODULE}.sv ../rtl/${MANDELBROT_CORE} ../rtl/${QMULT_MODULE}.sv --exe ${CPP_FILE}

# Build
make -C obj_dir -f V${TOP_MODULE}.mk V${TOP_MODULE}

# Run
./obj_dir/V${TOP_MODULE}
