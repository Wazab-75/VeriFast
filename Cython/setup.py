# setup.py
from setuptools import setup, Extension
from Cython.Build import cythonize
import numpy as np
import platform

# Configure compiler options based on platform
if platform.system() == 'Windows':
    extra_compile_args = ['/openmp']
    extra_link_args = ['/openmp']
else:
    # PYNQ FPGA optimizations
    extra_compile_args = [
        '-fopenmp',
        '-O3',  # Maximum optimization
        '-march=native',  # Use native architecture
        '-ffast-math',  # Fast math operations
        '-funroll-loops',  # Unroll loops
        '-ftree-vectorize',  # Enable vectorization
        '-DNDEBUG',  # Disable assertions
        '-fomit-frame-pointer',  # Optimize stack usage
        '-mfpmath=sse',  # Use SSE for floating point
        '-msse2',  # Enable SSE2 instructions
        '-msse3',  # Enable SSE3 instructions
        '-mssse3',  # Enable SSSE3 instructions
        '-msse4.1',  # Enable SSE4.1 instructions
        '-msse4.2',  # Enable SSE4.2 instructions
    ]
    extra_link_args = ['-fopenmp']

ext = Extension(
    name="fractal_core",
    sources=["fractal_core.pyx"],
    include_dirs=[np.get_include()],
    extra_compile_args=extra_compile_args,
    extra_link_args=extra_link_args,
    define_macros=[('NPY_NO_DEPRECATED_API', 'NPY_1_7_API_VERSION')],
)

setup(
    ext_modules=cythonize(
        [ext],
        compiler_directives={
            "language_level": "3",
            "boundscheck": False,
            "wraparound": False,
            "cdivision": True,
            "initializedcheck": False,
            "nonecheck": False,
            "overflowcheck": False,
            "embedsignature": False,
        },
    ),
)