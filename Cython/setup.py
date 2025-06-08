# setup.py
from setuptools import setup, Extension
from Cython.Build import cythonize
import numpy
import platform

# Configure compiler options based on platform
if platform.system() == 'Windows':
    extra_compile_args = ['/openmp']
    extra_link_args = ['/openmp']
else:
    extra_compile_args = ['-fopenmp', '-O3', '-march=native']
    extra_link_args = ['-fopenmp']

ext_modules = [
    Extension(
        "fractal_core",
        ["fractal_core.pyx"],
        include_dirs=[numpy.get_include()],
        extra_compile_args=extra_compile_args,
        extra_link_args=extra_link_args,
    )
]

setup(
    ext_modules=cythonize(ext_modules, compiler_directives={'language_level': "3"}),
)
