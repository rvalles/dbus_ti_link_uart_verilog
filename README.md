# Verilog UART to DBus (TI transfer bus, TI Link)

Use FPGA of choice to link a UART with a TI calculator.

Features
* Should work with all TI calculators featuring TI Link.
  * Tested with TI-89 (HW2) and TI Voyage 200 (HW2).
* Verilog 2005.
  * No dependency on vendor libraries.
  * Made for yosys+nextpnr open fpga flow.
* Custom dbus and uart implementations.
* Ring FIFO buffer in both directions.
  * Buffer infers FPGA-specific dual port RAM.
* Parametrized UART speed, FPGA clock, buffer sizes.
* Tested on iCE40 HX/LP FPGAs.
* Fast. Faster than official cables. Fastest. Calculator as bottleneck.
  * ~9.6KB/s from TI-89 (stock) with FPGA running dbus at 8MHz.
* MIT license. Refer to LICENSE file.

Tested FPGA boards
* iCEstick
* TinyFPGA BX
* (...)

Recommendations
* TI-89, TI-92+ or Voyage 200 are fast enough to take advantage of this.
  * These calculators work reliably with dbus running at 8MHz.
  * Lower end devices might work better with lower dbus rate.
* Be careful with FPGA i/o pin tolerance. TI dbus is maintained at 3.3v.
* Edit Makefile to uncomment or add fpga board.
* Edit board PCF to suit board board and preference.
* Preferably connect 2.5mm jack sleeve to GND rather than o_sleeve.
* Use pullup resistors (10kΩ suggested) on dbus tip/ring.
* If using tilp/libticables2, you'll need to patch it for the uart/rate.
  * Like this: https://gist.github.com/rvalles/0a7b076810470e8e4e2e0f1662eb70da

Thanks
* Tim Singer/Romain Liévin for TI-73...V200 protocol guide.
