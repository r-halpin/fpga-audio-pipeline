# fpga-audio-pipeline
FPGA-based audio sampling pipeline using the ADS1115 ADC over I²C, with real-time UART transmission to a Python interface. Includes Verilog implementation, DSP in Python (bias removal, normalization), .wav export, and signal analysis via FFT. Built on Basys 3 at up to 860 SPS.

# FPGA Audio Sampling with ADS1015

This project implements a real-time audio acquisition and processing pipeline using a Digilent Basys 3 FPGA board, the ADS1015 ADC, and Python for data visualization and DSP.

---

## 🔧 Hardware Overview

- **FPGA Board:** Digilent Basys 3 (100 MHz clock)
- **ADC:** ADS1015 (12-bit, up to 2400 SPS)
- **Microphone Input:** Analog signal to AIN0
- **Interfaces:**
  - **I²C:** SDA/SCL between FPGA and ADS1015
  - **UART:** 16-bit sample transmission from FPGA to PC

---

## 🧠 System Architecture

```text
Mic → ADS1015 → I2C → FPGA → UART → Python → WAV/FFT
