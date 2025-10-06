# FPGA Audio Sampling System

## Overview

FPGA-based audio sampling pipeline using the **ADS1115 ADC** over **I²C**, with real-time **UART transmission** to a **Python interface**.  
Includes:
- Verilog implementation (I²C, UART, top module)
- DSP in Python (bias removal, normalization)
- `.wav` export and signal analysis via FFT

Built on a **Basys 3** board, with sampling rates up to **860 SPS**.

---

## Hardware

- **FPGA:** Basys3 Artix-7
- **ADC:** ADS1115 (16-bit, I²C interface)
- **Microphone:** MAX4466 Electret Microphone with amplifier

The ADC and microphone were connected via breakout boards and wired on a breadboard to allow connection between the sensor and FPGA I/O pins.

---

## FPGA Components

### 🔹 I²C Communications Module

- Implements a finite state machine to control communication with the ADS1115 over I²C.
- Starts by sending an initial **5-byte configuration write** to the ADC  
  *(see: `docs/i2c_config_write_bytes.png`)*
- Continues with repeated **conversion read sequences** to acquire ADC samples  
  *(see: `docs/i2c_read_response_bytes.png`)*
- For more detail, refer to the **ADS111x datasheet**

---

### 🔹 UART Transmission Module

- Sends 16-bit audio samples from the I²C module to the PC over UART.
- Transmits data in **two 8-bit UART frames** (MSB first)
- Each frame follows standard **10-bit UART format**:  
  `1 start bit`, `8 data bits`, `1 stop bit`
- Operates at a configurable **baud rate** (default: **460800**)

---

### 🔹 Top Module

- Connects the I²C and UART modules
- Captures each 16-bit ADC sample
- Splits and sends the sample via UART in two frames
- Manages control logic to avoid lost or repeated transmissions

---

## Python Interface

A Python script receives the audio samples over UART and processes them:

- Reads two bytes per sample from the serial port (`/dev/ttyUSB1`)
- Reconstructs signed 16-bit integers (MSB first)
- Applies basic DSP:
  - Removes **DC offset**
  - **Normalizes** the waveform
- Saves output to `recorded_signal.wav` at **860 Hz**
- Optional: FFT and waveform plotting for analysis/debugging

---

