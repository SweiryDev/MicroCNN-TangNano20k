# FPGA MicroCNN Accelerator

An end-to-end System-on-Chip (SoC) implementing a quantized Convolutional Neural Network (MicroCNN) on a Gowin Tang Nano 20K FPGA ($25 board). This project classifies biological images from the BloodMNIST dataset via a custom hardware datapath, bridging the gap between Python-based machine learning and physical silicon acceleration.

## Overview
This repository contains the complete RTL infrastructure, testbenches, and software host scripts required to stream raw image pixels over UART, compute convolutions and fully-connected layers entirely in hardware, and return the classification result. 

By utilizing dynamic clock gating and a custom Master FSM, the accelerator achieves an inference latency of **~60 ms** running at 30 MHz, significantly outperforming an interpreted Python loop benchmark on a modern laptop CPU (~120 ms).

### Key Features
*   **Custom Microarchitecture:** Fully pipelined 3x3 Spatial MAC arrays, unified line buffers, and TDM routers written in SystemVerilog.
*   **INT8/INT32 Quantization:** Weights are quantized to INT8 and biases to INT32, utilizing cascaded scale factors for bit-accurate precision.
*   **Glitchless Clock Gating:** Integrates the Gowin DCS (Dynamic Clock Selector) to paralyze the NPU datapath during idle states, dropping dynamic power consumption.
*   **UART Bridge:** A self-recovering SoC command controller that handles image buffering and prevents in-band signaling collisions during transmission.
*   **Customizable Training Pipeline:** The network's weights and biases can be retrained and re-quantized using the provided Jupyter notebook for custom classification purposes.

## Network Architecture
The hardware datapath implements the following Convolutional Neural Network structure:

| Layer | Type | Channels / Dimensions (In $\rightarrow$ Out) | Feature Map Size | Scale Factor |
| :--- | :--- | :--- | :--- | :--- |
| **1** | Conv2d | 3 $\rightarrow$ 8 | 28x28 $\rightarrow$ 26x26 | - |
| **2** | ReLU | 8 $\rightarrow$ 8 | 26x26 $\rightarrow$ 26x26 | - |
| **3** | Scale | 8 $\rightarrow$ 8 | 13x13 $\rightarrow$ 13x13 | / 512 |
| **4** | MaxPool2d | 8 $\rightarrow$ 8 | 26x26 $\rightarrow$ 13x13 | - |
| **5** | Conv2d | 8 $\rightarrow$ 16 | 13x13 $\rightarrow$ 11x11 | - |
| **6** | ReLU | 16 $\rightarrow$ 16 | 11x11 $\rightarrow$ 11x11 | - |
| **7** | Scale | 16 $\rightarrow$ 16 | 11x11 $\rightarrow$ 11x11 | / 256 |
| **8** | MaxPool2d | 16 $\rightarrow$ 16 | 11x11 $\rightarrow$ 5x5 | - |
| **9** | Flatten | 16 $\rightarrow$ 1 | 11x11 $\rightarrow$ 400 | - |
| **10** | Linear | 1 $\rightarrow$ 1 | 400 $\rightarrow$ 32 | - |
| **11** | ReLU | 1 $\rightarrow$ 1 | 32 $\rightarrow$ 32 | - |
| **12** | Scale | 1 $\rightarrow$ 1 | 32 $\rightarrow$ 32 | / 512 |
| **13** | Linear | 1 $\rightarrow$ 1 | 32 $\rightarrow$ 8 | - |
| **14** | Argmax | 1 $\rightarrow$ 1 | 8 $\rightarrow$ 1 | - |

*(Note: Scale factors are applied via hardware shift divisors to manage INT32 accumulation growth).*

## Repository Structure

*   `src/`: Contains all SystemVerilog RTL modules, including the Top SoC wrapper, FSMs, computation layers, and Gowin IP cores (rPLL, DCS, SPDB).
*   `tb/`: SystemVerilog testbenches for individual module verification.
*   `hardware_roms/`: Pre-compiled INT8/INT32 hexadecimal memory files for layer weights, biases, and static test images.
*   `hardware_sim_vectors/`: Intermediate tap points generated for bit-accurate hardware-software simulation matching.
*   `uart_medmnist_loader.py`: **The primary FPGA communication script.** Handles UART communication, loads the BloodMNIST images, streams them to the FPGA, and reads the classification output.
*   `golden_benchmark.py`: A Python baseline script to test the software execution time of the quantized model for direct comparison against the FPGA.
*   `model.ipynb`: The core research notebook containing the training pipeline, FP32 parameter extraction, and quantization routines.

## Hardware Setup

*   **Board:** Sipeed Tang Nano 20K
*   **System Clock:** 30 MHz (Overclocked from the 27 MHz onboard oscillator via rPLL).
*   **UART Configuration:** 115200 Baud, 8N1.
    *   **UART RX (Host to FPGA):** Pin 70
    *   **UART TX (FPGA to Host):** Pin 69

## Usage

### 1. Synthesize and Flash
Open `NPU.gprj` in the Gowin EDA. Run the Synthesis and Place & Route pipeline. Flash the resulting `NPU.fs` bitstream to the Tang Nano 20k SRAM or embedded Flash. *(Note: The `.fs` file is excluded from version control and should be uploaded manually to the Releases section).*

### 2. Run the Hardware Accelerator
Use the Python loader script to select an image index from the BloodMNIST test dataset, stream it to the FPGA, and receive the hardware prediction.

```bash
# Example: Send BloodMNIST test image at index 26
python uart_medmnist_loader.py 26 --port /dev/ttyUSB1 --baud 115200
```

### 3. Run the Software Benchmark
Compare the hardware performance against your PC by running the software golden model on the same image index:

```bash
python golden_benchmark.py 26
```