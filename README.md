# IR Transmitter and Receiver

**Difficulty:** Intermediate

**MCU:** RP2040 / RP2350 (Shrike board)

**External hardware:** IR LED, TSOP1738 (or compatible 38 kHz IR receiver), current-limiting resistor (~70 Ω), breadboard, jumper wires

## Overview

A complete NEC infrared transmitter and receiver built on the Shrike eFPGA board. All of the timing-critical work runs in the FPGA fabric: 38 kHz carrier generation, NEC frame encoding, and NEC frame decoding (including repeat codes). The RP2040 only sends a 3-byte command and reads back a 3-byte result over a simple two-wire link.

A NEC frame is 32 bits — address, inverted address, command, inverted command — modulated onto a 38 kHz carrier with a 9 ms leader. The FPGA produces this entirely in hardware, so the MCU side stays trivial.

The end-to-end path is:

```
RP2040  --2-wire-->  FPGA NEC encoder  -->  38 kHz carrier  -->  IR LED
                                                                    |
                                                                  (air)
                                                                    v
RP2040  <--2-wire--  FPGA NEC decoder  <--  TSOP1738  <-------------+
```

## MCU – FPGA link

The Shrike's internal SPI/UART configuration pins (FPGA pins 3–6) are held by the configuration logic after the bitstream is flashed and are not usable as general I/O from MicroPython. The dedicated GPIO/I2C pins were also not reliably broken out on this unit. The link is therefore made with three jumper wires between the MCU header and the FPGA header, using a small bit-banged protocol clocked by the MCU. Because the MCU supplies the clock, the transfer is immune to the FPGA oscillator's tolerance (which made a plain UART unreliable).

### Wiring

| Signal   | MCU pin   | FPGA pin   | Direction   | Notes                         |
| -------- | --------- | ---------- | ----------- | ----------------------------- |
| DATA     | GPIO5     | FPGA_IO0   | MCU → FPGA  | command bits in               |
| CLOCK    | GPIO6     | FPGA_IO1   | MCU → FPGA  | shared shift clock            |
| RETURN   | GPIO7     | FPGA_IO18  | FPGA → MCU  | decoded result out            |
| IR LED   | —         | FPGA_IO7   | FPGA → LED  | 38 kHz modulated output       |
| TSOP OUT | —         | FPGA_IO8   | TSOP → FPGA | demodulated NEC input (PMOD)  |
| FPGA LED | —         | GPIO16     | on-board    | heartbeat / decode indicator  |

IR LED: `FPGA_IO7 → ~70 Ω → anode`, cathode to GND.
TSOP1738 (dome facing you, pins down — GND, VCC, OUT): `GND → GND`, `VCC → 3.3 V`, `OUT → FPGA_IO8`.

> All Shrike I/O is 3.3 V. Confirm the exact pad assignments in `IR_PROJECT.ffpga` (IO Planner) before wiring.

## Two-wire protocol

**MCU → FPGA (send a command).** The MCU shifts 24 bits, MSB first, toggling DATA then pulsing CLOCK for each bit:

| Byte | Meaning                                  |
| ---- | ---------------------------------------- |
| 0    | type — `0x01` = data frame, `0x02` = repeat |
| 1    | address                                  |
| 2    | command                                  |

A `0x01`/`0x02` command makes the FPGA transmit the corresponding NEC frame on the IR LED.

**FPGA → MCU (read a result).** After a frame is decoded from the TSOP, the FPGA drives RETURN high and presents a 24-bit result. The MCU reads it MSB first using *read-before-clock*: sample RETURN while it is stable, then pulse CLOCK to advance to the next bit.

| Byte | Meaning                                          |
| ---- | ------------------------------------------------ |
| 0    | status — `0x81` = valid data, `0x82` = repeat, `0x00` = nothing |
| 1    | decoded address                                  |
| 2    | decoded command                                  |

Each new `0x01`/`0x02` command clears the previous result, so a stale frame is never read back.

## FPGA design (`ffpga/src`)

| File                  | Role                                                            |
| --------------------- | --------------------------------------------------------------- |
| `modulator.v`         | Top module `ir_top` — link, command parser, result serializer   |
| `nec_encoder.v`       | NEC frame state machine (leader, 32 bits, stop, repeat, gap)    |
| `carrier_generator.v` | 38 kHz carrier (counter = 661 for the measured 50.33 MHz clock) |
| `nec_decoder.v`       | NEC decoder with timing windows and glitch rejection            |

The carrier divider and the decoder windows are tuned to the on-board oscillator, which measured 50.33 MHz (counter 661 gives a 38 kHz carrier). The decoder ignores premature TSOP transitions until each segment reaches its minimum expected length, which rejects the TSOP AGC glitches that otherwise corrupt the leader.

## MicroPython (`firmware/micropython`)

`demo.py` is a self-contained showcase: it flashes the bitstream, explains the NEC frame, then transmits a set of commands and reads each one back through the IR loopback.

Copy `demo.py` and `bitstream/FPGA_bitstream_MCU.bin` to the RP2040 and run `demo.py` in Thonny. Point the IR LED at the TSOP from a few centimetres away (too close saturates the TSOP, too far drops the signal).

Expected output:

```
Live transmit + decode round-trips:
    Addr  Cmd   Decoded    Tries  Status
    ----------------------------------------
    0x12 0x34   0x12/0x34     1   OK
    0x00 0x20   0x00/0x20     1   OK
    0x00 0x21   0x00/0x21     1   OK
    0xA5 0x5A   0xA5/0x5A     1   OK
    0xFF 0x0F   0xFF/0x0F     1   OK
    ----------------------------------------
    5/5 commands transmitted and decoded correctly
```

## Simulation

The full encode → loopback → decode path can be verified with Icarus Verilog and viewed in GTKWave. The testbench models the TSOP as an active-low demodulator of the carrier.

```bash
cd ffpga/sim
iverilog -o tb_ir_loopback.vvp tb_ir_loopback.v
vvp tb_ir_loopback.vvp
gtkwave tb_ir_loopback.vcd
```

Expected output:

```
[2000000] Sending NEC command: type=0x01 addr=0x12 cmd=0x34
[68099690000] DECODED  addr=0x12  cmd=0x34
RESULT: PASS  (loopback decode matches transmitted frame)
```

Useful signals in GTKWave: `mod_enable` (NEC envelope — leader, bits, stop), `ir_out`/`carrier` (38 kHz), `tsop_in` (demodulated), `dec_valid`, `dec_addr`, `dec_cmd`.

## File structure

```
IR_PROJECT/
├── IR_PROJECT.ffpga              # Shrike (Go Configure) project file
├── bitstream/
│   └── FPGA_bitstream_MCU.bin    # compiled bitstream to flash
├── ffpga/
│   ├── src/                      # Verilog sources
│   └── sim/                      # testbenches (tb_ir_loopback.v)
├── firmware/micropython/         # RP2040 scripts
├── images/                       # waveforms / diagrams
└── README.md
```

## Build

Open `IR_PROJECT.ffpga` in Renesas Go Configure (ForgeFPGA Workshop), set the IO Planner to the pins in the wiring table, synthesise, and generate the bitstream. Flash it from MicroPython with `shrike.flash("FPGA_bitstream_MCU.bin")`.
