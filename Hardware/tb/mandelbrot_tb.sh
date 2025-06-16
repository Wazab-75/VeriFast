#!/bin/bash
rm -rf obj_dir

# Exit if any command fails
set -e

# Variables
TOP_MODULE="mandelbrotCore"
QMULT_MODULE="qMult_sc"
CPP_FILE="mandelbrot_tb"

# Run Verilator
verilator --sv -Wall --cc --trace ../rtl/${TOP_MODULE}.sv ../rtl/${QMULT_MODULE}.sv --exe ${CPP_FILE}.cpp

# Build
make -C obj_dir -f V${TOP_MODULE}.mk V${TOP_MODULE}

# Run
./obj_dir/V${TOP_MODULE}

