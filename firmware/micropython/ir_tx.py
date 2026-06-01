from machine import Pin
import time

class NECTransmitter:
    def __init__(self, sck_pin=2, sdi_pin=1, tx_en_pin=0, busy_pin=14):
        self.sck = Pin(sck_pin, Pin.OUT, value=0)
        self.sdi = Pin(sdi_pin, Pin.OUT, value=0)
        self.tx_en = Pin(tx_en_pin, Pin.OUT, value=0)
        self.busy = Pin(busy_pin, Pin.IN)

    def _shift_out(self, data16):
        self.tx_en.value(0)
        # Shift out 16 bits LSB first
        # First bit shifted ends up at shreg[0] in the FPGA
        for i in range(16):
            self.sdi.value((data16 >> i) & 1)
            self.sck.value(1)
            self.sck.value(0)

    def send(self, address, command):
        # shreg[7:0] will be addr, shreg[15:8] will be cmd
        address = address & 0xFF
        command = command & 0xFF
        data16 = (command << 8) | address
        
        self._shift_out(data16)
        
        # Pulse TX Enable to start transmission
        self.tx_en.value(1)
        self.tx_en.value(0)
        
        # Wait for FPGA to finish
        time.sleep_ms(1) # wait for busy to rise
        while self.busy.value() == 1:
            pass
        print(f"TX done  addr=0x{address:02X}  cmd=0x{command:02X}")

    def repeat(self):
        # 0xFFFF is the special command we added for repeat code
        self._shift_out(0xFFFF)
        self.tx_en.value(1)
        self.tx_en.value(0)
        
        time.sleep_ms(1)
        while self.busy.value() == 1:
            pass
        print("TX repeat done")
