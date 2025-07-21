# VeriFast – FPGA-Accelerated Fractal Visualisation System

## Overview

VeriFast is a real-time fractal visualisation system that renders Mandelbrot and Julia sets using FPGA-based hardware acceleration on a PYNQ-Z1 board. By offloading computation to a custom accelerator written in Verilog and SystemVerilog, the system achieves performance gains of over 40× compared to traditional CPU-based methods.

A responsive web interface, built with Flask and hosted on AWS, allows users to interact with the fractals in real-time. Parameters such as zoom level, iteration depth, and colour scheme can be adjusted dynamically. Users can also download high-resolution fractal images for offline use or view them directly through the HDMI output on the FPGA board.

![Interface](/Images/Interface.jpeg)
