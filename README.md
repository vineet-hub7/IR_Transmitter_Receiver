# IR Transmitter and Receiver

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** IR LED, TSOP1838 IR Receiver, Shrike Board, Breadboard, Jumper Wires

## Overview

This example implements a full NEC infrared transmitter and receiver using the Shrike board. The FPGA handles 38kHz carrier generation, NEC protocol encoding/decoding, and repeat code processing. The RP2040 communicates with the FPGA over a custom SPI interface to send and receive IR commands.

The NEC protocol transmits 32 bits per frame: 8-bit address, inverted address, 8-bit command, and inverted command. Data is modulated onto a 38kHz carrier with precise burst timings (562.5us marks, 1.6875ms spaces for logic 1). The FPGA generates all of this natively in hardware, so the MCU only needs to shift in 16 bits and pulse a trigger pin.

## Requirements

- Shrike board (any variant)
- IR LED (940nm recommended)
- TSOP1838 IR receiver module
- Breadboard
- Jumper wires
- 100 ohm resistor (current limiting for IR LED)

## Hardware Setup

### IR LED (Transmitter)

Connect the IR LED to the FPGA output pin through a 100 ohm current limiting resistor.

- FPGA `ir_out` pin → 100Ω Resistor → IR LED Anode
- IR LED Cathode → GND

### TSOP1838 (Receiver)

The TSOP module has 3 pins: OUT, GND, VCC.

- TSOP OUT → FPGA `tsop_in` pin
- TSOP GND → GND
- TSOP VCC → 3.3V

### Pin Connections

| Signal       | Direction   | FPGA Pin | Description                     |
| ------------ | ----------- | -------- | ------------------------------- |
| mcu_sck      | MCU → FPGA  | PIN 3    | SPI clock                       |
| mcu_sdi      | MCU → FPGA  | PIN 4    | SPI data in (address + command) |
| mcu_sdo      | FPGA → MCU  | PIN 5    | SPI data out (decoded frame)    |
| mcu_tx_en    | MCU → FPGA  | PIN 6    | Trigger transmission            |
| mcu_rx_valid | FPGA → MCU  | PIN 17   | Frame decoded, ready to read    |
| mcu_tx_busy  | FPGA → MCU  | PIN 18   | Transmission in progress        |
| ir_out       | FPGA → LED  | PIN 21   | Modulated 38kHz carrier output  |
| tsop_in      | TSOP → FPGA | PIN 22   | Demodulated NEC input           |

## How It Works

1. MCU shifts 16 bits into the FPGA via SPI (8-bit address + 8-bit command, LSB first)
2. MCU pulses `mcu_tx_en` high to start transmission
3. FPGA asserts `mcu_tx_busy` and generates the full NEC frame on `ir_out`
4. On the receive side, TSOP demodulates the 38kHz carrier and feeds a clean envelope into `tsop_in`
5. FPGA decodes the NEC frame and asserts `mcu_rx_valid`
6. MCU clocks out the decoded 16 bits via `mcu_sdo`
7. Sending address=0xFFFF triggers a repeat code (9ms burst + 2.25ms space)

## File Structure

```
IR_PROJECT/
├── IR_PROJECT.ffpga
├── ffpga/
│   ├── src/
│   │   ├── tb_ir_top.v          # top-level wrapper
│   │   ├── modulator.v          # SPI interface + control logic
│   │   ├── nec_encoder.v        # NEC TX encoder
│   │   ├── nec_decoder.v        # NEC RX decoder
│   │   └── carrier_generator.v  # 38kHz carrier
│   └── sim/
│       └── tb_ir_top.v          # testbench
└── README.md
```

## Simulation

Run with Icarus Verilog:

```
cd ffpga/sim
iverilog -o tb_ir_top.vvp tb_ir_top.v ../src/tb_ir_top.v
vvp tb_ir_top.vvp
```

Expected output:

```
=== NEC IR Loopback Tests | 50 MHz ===
PASS [DATA   addr=0x12 cmd=0x34]: got 0x3412
PASS [REPEAT 0xFFFF]: got 0xFFFF
======================================
ALL TESTS PASSED
======================================
```
