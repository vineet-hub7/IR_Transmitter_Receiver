# NEC IR Transceiver for Vicharak Shrike

Hardware-accelerated NEC IR transmitter and receiver for the Shrike board. The FPGA handles all the 38kHz modulation, NEC encoding/decoding, and repeat code generation. The RP2040 just sends address + command over SPI.

## How it works

- MCU shifts 16 bits (8-bit address + 8-bit command) into the FPGA via SPI
- FPGA generates the full 32-bit NEC frame with proper timing (9ms leader, 4.5ms space, 562.5us/1.6875ms data bits)
- On receive side, TSOP feeds into the FPGA which decodes the frame and shifts it back to the MCU
- Repeat codes (0xFFFF) are handled natively in hardware

## Pinout

| Signal | Direction | Pin |
| --- | --- | --- |
| mcu_sck | MCU -> FPGA | PIN 3 |
| mcu_sdi | MCU -> FPGA | PIN 4 |
| mcu_sdo | FPGA -> MCU | PIN 5 |
| mcu_tx_en | MCU -> FPGA | PIN 6 |
| mcu_rx_valid | FPGA -> MCU | PIN 17 |
| mcu_tx_busy | FPGA -> MCU | PIN 18 |
| ir_out | FPGA -> IR LED | Any free pin |
| tsop_in | TSOP -> FPGA | Any free pin |

## Structure

```
IR_PROJECT/
├── IR_PROJECT.ffpga          # source project file
├── bitstream/
│   └── IR_PROJECT.bin        # compiled bitstream
├── ffpga/
│   ├── src/                  # verilog source
│   │   ├── modulator.v       # top module with SPI + NEC logic
│   │   ├── nec_encoder.v     # NEC TX encoder
│   │   ├── nec_decoder.v     # NEC RX decoder
│   │   ├── carrier_generator.v
│   │   └── tb_ir_top.v       # top-level wrapper
│   └── sim/
│       └── tb_ir_top.v       # testbench
└── README.md
```

## Simulation

Tested with Icarus Verilog. TX sends address 0x12, command 0x34 and the waveform shows correct NEC timing on all signals. RX decodes the loopback correctly.
