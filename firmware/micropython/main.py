import shrike
import time
from ir_tx import NECTransmitter
from ir_rx import NECReceiver

shrike.flash("FPGA_bitstream_MCU.bin")
print("FPGA bitstream flashed.")

tx = NECTransmitter(sck_pin=2, sdi_pin=1, tx_en_pin=0, busy_pin=14)
rx = NECReceiver(sck_pin=2, sdo_pin=3, rx_valid_pin=15)

time.sleep_ms(100)

print("Starting Loopback Test...")

print("\n--- Sending Normal Frame ---")
tx.send(address=0x12, command=0x34)

result = rx.receive(timeout_ms=5000)
if result is None:
    print("RX: No signal received")
elif result == 'REPEAT':
    print("RX: Repeat code")
else:
    addr, cmd = result
    print(f"RX: Received addr=0x{addr:02X} cmd=0x{cmd:02X}")
    if addr == 0x12 and cmd == 0x34:
        print("    -> Normal Frame Loopback SUCCESS!")
    else:
        print("    -> Normal Frame Loopback FAILED (mismatch)")

print("\n--- Sending Repeat Frame ---")
tx.repeat()

result = rx.receive(timeout_ms=5000)
if result is None:
    print("RX: No signal received")
elif result == 'REPEAT':
    print("RX: Repeat code")
    print("    -> Repeat Frame Loopback SUCCESS!")
else:
    addr, cmd = result
    print(f"RX: Received normal frame instead of repeat: addr=0x{addr:02X} cmd=0x{cmd:02X}")
    print("    -> Repeat Frame Loopback FAILED")

print("\nLoopback test finished.")
