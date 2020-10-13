# Verilog UART to DBus (TI transfer bus, TI Link)

Use FPGA of choice to link a UART with a TI calculator.

Features
* Should work with all TI calculators featuring TI Link.
  * Tested with TI-89 (HW2) and TI Voyage 200 (HW2).
* Fast. Faster than official cables. Fastest. Calculator as bottleneck.
  * ~77Kbit/s from TI-89 (HW2 stock) with FPGA running dbus at 8MHz.
* Verilog 2005.
  * No dependency on vendor libraries.
  * Made for yosys+nextpnr open fpga flow.
  * Tested on iCE40 HX/LP FPGAs.
* Custom dbus and uart implementations.
* Parametrized UART rate, DBus clock, buffer sizes.
* Hardware flow control.
* Ring FIFO buffer in both directions.
  * Buffer infers FPGA-specific dual port RAM.
* Timeout (2s) on dbus bit transfer:
  * Error signal (grounds both lines for ~300µs) and dbus reset.
* MIT license. Refer to LICENSE file.

Tested FPGA boards
* iCEstick
* TinyFPGA BX
* (...)

Recommendations
* TI-89, TI-92+ or Voyage 200 are fast enough to take advantage of this.
  * These calculators work reliably with dbus running at 8MHz.
  * Lower end z80 devices might work better with lower dbus rate.
* Be careful with FPGA i/o pin tolerance. TI dbus is maintained at 3.3v.
* Edit Makefile to uncomment or add fpga board.
* Edit board PCF to suit board board and preference.
* Preferably connect 2.5mm jack sleeve to GND rather than o_sleeve.
* Use pullup resistors (10kΩ suggested) on dbus tip/ring.
* If using tilp/libticables2:
  * No support for plain uart. Pretend it's a grey cable.
  * Patch grey cable for the uart device/rate/hwflow.
    * Like this: https://gist.github.com/rvalles/f937889712d24ac6824f1358c936b3e2
  * If using an uart without hw flow control support with TILP:
    * Use this older patch: https://gist.github.com/rvalles/0a7b076810470e8e4e2e0f1662eb70da
    * See caveats.
* If using TI official software:
  * Pretend it's a grey graphlink cable.
  * Use 9600bps, like a grey graphlink cable.

Caveats
* tilp/libticables2 likes to send files in large packets.
  * Some devboards have buffer size to calculator below 4KB. These will fill faster than can be sent.
  * Flow control takes care of it, and thus it is not an issue.
  * If uart flow control is not possible, workaround is to set a slower uart speed in Makefile and in libticables2.
    * 57600bps is slow enough for m68k calculator models.

TODO
* Write some basic link software as an alternative to TILP.

Thanks
* Tim Singer/Romain Liévin for TI-73...V200 protocol guide.
