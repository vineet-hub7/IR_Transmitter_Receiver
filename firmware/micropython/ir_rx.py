from machine import Pin
import time

class NECReceiver:
    def __init__(self, sck_pin=2, sdo_pin=3, rx_valid_pin=15):
        self.sck = Pin(sck_pin, Pin.OUT, value=0)
        self.sdo = Pin(sdo_pin, Pin.IN)
        self.rx_valid = Pin(rx_valid_pin, Pin.IN)

    def _shift_in(self):
        data16 = 0
        # The first bit (MSB) is already on the SDO line before the first clock
        for i in range(16):
            # Read the current bit
            bit = self.sdo.value()
            data16 = (data16 << 1) | bit
            
            # Clock the next bit out
            self.sck.value(1)
            self.sck.value(0)
            
        return data16

    def receive(self, timeout_ms=150):
        """
        Returns (address, command) on success
        Returns 'REPEAT' on repeat code
        Returns None on timeout
        """
        start = time.ticks_ms()
        # Wait for rx_valid to go high (polling)
        while self.rx_valid.value() == 0:
            if time.ticks_diff(time.ticks_ms(), start) > timeout_ms:
                return None
                
        # Data is ready! Read it.
        data16 = self._shift_in()
        
        if data16 == 0xFFFF:
            return 'REPEAT'
            
        # Data is {cmd[7:0], addr[7:0]}
        cmd = (data16 >> 8) & 0xFF
        addr = data16 & 0xFF
        
        return (addr, cmd)