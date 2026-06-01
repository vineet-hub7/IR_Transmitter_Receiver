# IR Transmitter and Receiver

**Difficulty:** Intermediate

**Uses MCU:** Yes (RP2040/RP2350)

**External Hardware:** IR LED, TSOP1738 (or similar) IR Receiver, Shrike Board, Breadboard, Jumper Wires

## Overview

This project implements a full NEC infrared transmitter and receiver using the Shrike FPGA board. The FPGA handles 38kHz carrier generation, NEC protocol encoding/decoding, and repeat code processing. The RP2040 communicates with the FPGA over a **UART interface** (115200 baud) to send and receive IR commands.

The NEC protocol transmits 32 bits per frame: 8-bit address, inverted address, 8-bit command, and inverted command. Data is modulated onto a 38kHz carrier with precise burst timings. The FPGA generates all of this natively in hardware, so the MCU only needs to send a simple 3-byte payload over UART.

## Hardware Setup

### IR LED (Transmitter)

Connect the IR LED to the FPGA output pin through a 100 ohm current limiting resistor.

- FPGA `ir_out` (e.g., `FPGA_IO7`) → 100Ω Resistor → IR LED Anode
- IR LED Cathode → GND

### TSOP1738 (Receiver)

The TSOP module has 3 pins: OUT, GND, VCC. Hold it with the front dome facing you and pins pointing down (Left to Right: GND, VCC, OUT).

- TSOP OUT → FPGA `tsop_in` pin (e.g., `FPGA_IO2`)
- TSOP GND → GND
- TSOP VCC → 3.3V

### Pin Connections (Example)

| Signal  | Direction   | Description                    |
| ------- | ----------- | ------------------------------ |
| uart_rx | MCU → FPGA  | UART RX on FPGA (115200 baud)  |
| uart_tx | FPGA → MCU  | UART TX from FPGA              |
| ir_out  | FPGA → LED  | Modulated 38kHz carrier output |
| tsop_in | TSOP → FPGA | Demodulated NEC input          |

_Check `IR_PROJECT.ffpga` IO planner for your exact pin mappings!_

## How It Works

1. **Python Script**: The MCU sends 3 bytes via UART to the FPGA at 115200 baud.
   - `Byte 1`: Command Type (`0x01` for DATA, `0x02` for REPEAT)
   - `Byte 2`: Address (`0x12`)
   - `Byte 3`: Command (`0x34`)
2. **FPGA Encoding**: The FPGA receives the UART command, generates the 38kHz carrier, and outputs the precise 9ms leading pulse followed by the 32-bit payload (or a 2.25ms gap + short burst for REPEAT) on `ir_out`.
3. **IR Transmission**: The IR LED flashes and the signal bounces into the TSOP receiver.
4. **FPGA Decoding**: The TSOP pulls `tsop_in` low during bursts. The FPGA decodes the NEC frame.
5. **Loopback**: Upon successful decode, the FPGA transmits the exact same 3 bytes back to the MCU over `uart_tx` to verify success!

## File Structure

```
IR_PROJECT/
├── IR_PROJECT.ffpga     # Shrike IDE project file
├── bitstream/
│   └── IR_project.bin   # Compiled bitstream ready to flash
├── ffpga/
│   ├── src/
│   │   ├── modulator.v          # Top-level integration (ir_top)
│   │   ├── uart_rx.v            # UART Receiver (115200 baud)
│   │   ├── uart_tx.v            # UART Transmitter (115200 baud)
│   │   ├── nec_encoder.v        # NEC TX encoder
│   │   ├── nec_decoder.v        # NEC RX decoder
│   │   └── carrier_generator.v  # 38kHz carrier
│   └── sim/
│       └── tb_ir_top.v          # Testbench testing full UART loopback
├── images/                      # Diagrams and waveform screenshots
├── main.py                      # MicroPython script for RP2040
└── README.md
```

## Simulation

You can verify the entire pipeline (including the UART loopback and the exact 38kHz IR modulation) using Icarus Verilog and GTKWave.

```bash
cd ffpga/sim
iverilog -o sim.vvp tb_ir_top.v ../src/modulator.v ../src/uart_rx.v ../src/uart_tx.v ../src/nec_encoder.v ../src/nec_decoder.v ../src/carrier_generator.v
vvp sim.vvp
```

Expected output:

```
=== NEC IR UART Loopback Tests | 50 MHz ===
[500000] Starting test: DATA   addr=0x12 cmd=0x34
PASS [DATA   addr=0x12 cmd=0x34]: got type=0x01 addr=0x12 cmd=0x34
[68706090000] Starting test:               REPEAT 0x02
PASS [              REPEAT 0x02]: got type=0x02 addr=0x12 cmd=0x34
========================================
ALL TESTS PASSED
========================================
```

Load `tb_ir_top.vcd` in GTKWave to view the exact waveforms!

![Pipeline Architecture](images/pipeline_architecture.png)
![Waveform Verification](images/waveform_verification.png)
