import struct
import time
import binascii

class TinyFPGAQ(object):
    def __init__(self, ser, progress=None):
        self.ser = ser
        self.spinner = 0
        if progress is None:
            self.progress = lambda x: x
        else:
            self.progress = progress

    def is_bootloader_active(self):
        time.sleep(0.1)
        for i in range(6):
            self.wake()
            time.sleep(0.001)
            self.read(0, 16)
            time.sleep(0.001)
            self.wake()
            time.sleep(0.001)
            devid = self.read_id()
            expected_devid = b'\xc8\x40\x15'
            if devid == expected_devid:
                return True
            time.sleep(0.05)
            self.progress("Unexpected device id")
            print( "unexpected qf dev id")
            print( binascii.hexlify(devid))
            print( len(devid))
        return False

    def cmd(self, opcode, addr=None, data=b'', read_len=0):
        assert isinstance(data, bytes)
        cmd_read_len = read_len + 1 if read_len else 0
        addr = b'' if addr is None else struct.pack('>I', addr)[1:]
        write_string = bytearray([opcode]) + addr + data
        cmd_write_string = b'\x01' + struct.pack(
            #'<HH', len(write_string), cmd_read_len) + write_string
            '<HH', len(write_string), read_len) + write_string
        self.ser.write(bytearray(cmd_write_string))
        self.ser.flush()
        response = self.ser.read(read_len)
        return response

    def sleep(self):
        self.cmd(0xb9)

    def wake(self):
        print( "RDI (release from power down) 0xAB")
        self.cmd(0xab)

    def read_id(self):
        print( "RDID 0x9F")
        return self.cmd(0x9f, read_len=3)

    def read_sts(self):
        return self.cmd(0x05, read_len=1) or '1'

    def read(self, addr, length, verbose=True):
        if (verbose):
            print( "FastREAD 0x0B (", length, ")")
            print( "[                                                 ]\r[", end='', flush=True)
        data = b''
        readsofar = 0
        chunk = length/50
        trigger = chunk
        while length > 0:
            read_length = min(16, length)
            data += self.cmd(0x0b, addr, b'\x00', read_len=read_length)
            #self.progress(read_length)
            addr += read_length
            length -= read_length
            readsofar += read_length
            if verbose and readsofar > trigger:
              print("X", end='', flush=True)
              trigger += chunk
        if verbose:
            print("]")
        return data

    def write_enable(self):
        #print "WriteEnable 0x06"
        self.cmd(0x06)

    def write_disable(self):
        print( "WriteDisable 0x04")
        self.cmd(0x04)

    def wait_while_busy(self):
        # FIXME: this is a workaround for a bug in the bootloader verilog.  if
        #        the status register read comes too early, then it corrupts the
        #        SPI flash write in progress.  this busy loop waits long enough
        #        such that the write data has finished and data corruption is
        #        no longer possible.
        self._delay_micros(70)
        while ord(self.read_sts()) & 1:
            self._delay_micros(10)

    def _erase(self, addr, length):
        opcode = {
            4 * 1024: 0x20,
            32 * 1024: 0x52,
            64 * 1024: 0xd8,
        }[length]
        self.write_enable()
        print( "Erase ", length/1024, "KiB (",hex(opcode),") at ", hex(addr))
        self.cmd(opcode, addr)
        self.wait_while_busy()

    def erase(self, addr, length):
        # This version does RMW, ie if not erasing entire sector, restores the part that was not requested to be erased
        possible_lengths = (1, 4 * 1024, 32 * 1024, 64 * 1024)

        while length > 0:
            erase_length = max(p for p in possible_lengths
                               if p <= length and addr % p == 0)
            if erase_length == 1:
                # there are no opcode to erase that much
                # either we want to erase up to multiple of 0x1000
                # or we want to erase up to length

                # start_addr                            end_addr
                # v                                     v
                # +------------------+------------------+----------------+
                # |       keep       |      erase       |      keep      |
                # +------------------+------------------+----------------+
                #  <- start_length -> <- erase_length -> <- end_length ->

                start_addr = addr & 0xfff000
                start_length = addr & 0xfff
                erase_length = min(0x1000 - start_length, length)
                end_addr = start_addr + start_length + erase_length
                end_length = start_addr + 0x1000 - end_addr

                # read data we need to restore later
                if start_length:
                    start_read_data = self.read(start_addr, start_length)
                if end_length:
                    end_read_data = self.read(end_addr, end_length)

                # erase the block
                self._erase(start_addr, 0x1000)

                # restore data
                if start_length:
                    self.write(start_addr, start_read_data)
                if end_length:
                    self.write(end_addr, end_read_data)

            else:
                # there is an opcode to erase that much data
                self.progress(erase_length)
                self._erase(addr, erase_length)

            # update
            length -= erase_length
            addr += erase_length
            
    def quick_erase(self, addr, length):
        # This version does not to RMW
        possible_lengths = (1, 4 * 1024, 32 * 1024, 64 * 1024)

        while length > 0:
            erase_length = max(p for p in possible_lengths
                               if p <= length and addr % p == 0)
            if erase_length == 1:
                # not doing the RMW thing, just erase the enclosing sector
                # (Still need the calcs to keep the adresses and lengths correct)
                start_addr = addr & 0xfff000
                start_length = addr & 0xfff
                erase_length = min(0x1000 - start_length, length)
                end_addr = start_addr + start_length + erase_length
                end_length = start_addr + 0x1000 - end_addr

                # erase the block
                self._erase(start_addr, 0x1000)

            else:
                # there is an opcode to erase that much data
                self.progress(erase_length)
                self._erase(addr, erase_length)

            # update
            length -= erase_length
            addr += erase_length

    def _delay_micros(self, micros):
        import timeit
        seconds = micros / 1000000.0
        t = timeit.default_timer()
        while timeit.default_timer() - t < seconds:
            self.spinner = (self.spinner + 1) & 0xff

    # don't use this directly, use the public "write" function instead
    def _write(self, addr, data):
        self.write_enable()
        #print("Write 0x02 (", len(data), ")")
        self.cmd(0x02, addr, data)
        #self._delay_micros(100000)
        self._delay_micros(10000)
        self.wait_while_busy()
        #self.progress(len(data))

    def write(self, addr, data):
        print( "Write ", len(data), " bytes")
        print( "[                                                 ]\r[", end='', flush=True)
        cnt = 0
        chunk = len(data)/50
        trigger = chunk
        while data:
            dist_to_256_byte_boundary = 256 - (addr & 0xff)
            write_length = min(len(data), dist_to_256_byte_boundary)
            self._write(addr, data[:write_length])
            data = data[write_length:]
            addr += write_length
            cnt += write_length
            if cnt > trigger:
              print("X", end='', flush=True)
              trigger += chunk
        print("]")

    def program(self, addr, data, what):
        self.progress("Erasing designated flash pages")
        print("Erasing designated flash pages")
        # Our memory map does not require rmw, so don;t do rmw
        self.quick_erase(addr, len(data))

        self.progress("Writing "+what)
        print("Writing ", what)
        self.write(addr, data)

        self.progress("Verifying "+what)
        print("Verifying ", what)
        read_back = self.read(addr, len(data))

        if read_back == data:
            print( "Success: read_back == data")
            self.progress("Success!")
            return True
        else:
            self.progress("Need to rewrite some pages...")
            quit()

            self.progress(
                "len: {:06x} {:06x}"
                .format(len(data), len(read_back)))

            mismatch_4k_pages = set()
            for i in range(min(len(data), len(read_back))):
                if read_back[i] != data[i]:
                    mismatch_4k_pages.add(i >> 12)

            for page in mismatch_4k_pages:
                page_offset = page << 12
                page_addr = addr + page_offset
                page_len = min(4 * 1024, len(data) - page_offset)
                page_data = data[page_offset:page_offset + page_len]
                self.progress("rewriting page {:06x}".format(page_addr))
                success = True
                for attempt in range(6):
                    self.erase(page_addr, page_len)
                    self.write(page_addr, page_data)
                    page_read_back_data = self.read(page_addr, page_len)

                    if len(page_read_back_data) != len(page_data):
                        success = False
                    else:
                        for i in range(page_len):
                            if page_read_back_data[i] != page_data[i]:
                                self.progress(
                                    "        diff {:06x}: {:02x} {:02x}"
                                    .format(
                                        i,
                                        ord(page_read_back_data[i]),
                                        ord(page_data[i])))
                                success = False

                    if success:
                        break
                    else:
                        time.sleep(0.1)

                if not success:
                    self.progress("Verification Failed!")
                    return False

            self.progress("Success!")
            return True

    def boot(self):
        self.ser.write(bytearray([0x00]))
        self.ser.flush()

    def slurp(self, filename):
        with open(filename, 'rb') as f:
            bitstream = f.read()
        if filename.endswith('.hex'):
            bitstream = ''.join(chr(int(i, 16)) for i in bitstream.split())
            print("Bitstream type: {}".format(type(bitstream)))
            bitstream = str.encode(bitstream)
        elif not filename.endswith('.bin'):
            raise ValueError('Unknown bitstream extension')
        return (0x80000, bitstream)

    def program_bitstream(self, addr, bitstream, what):
        self.progress("Waking up SPI flash")
        self.progress(str(len(bitstream)) + " bytes to program")
        if self.program(addr, bitstream, what):
            #self.boot()
            return True

        # FIXME: printing out this spinner ensures the busy loop in _write is
        #        not optimized away
        print("Your lucky number: " + str(self.spinner))

        return False
