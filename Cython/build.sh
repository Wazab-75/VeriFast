#!/bin/bash
echo "Building optimized Cython extension..."
python setup.py build_ext --inplace
echo "Build complete!" 