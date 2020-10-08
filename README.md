# Verilog UART to DBus (TI transfer bus, TI Link)

Use FPGA of choice to link an UART with a TI calculator.

Features:
* Verilog 2005.
* No dependency on vendor libraries.
* Made for yosys, nextpnr flow.
* Custom dbus and uart implementations.
* Tested on iCE40 HX/LP FPGAs.
* Fast. Faster than official TI graph link cables. Calculator as bottleneck.
* MIT license. Refer to LICENSE file.

Supported boards:
* iCEstick
* TinyFPGA BX
* (...)

Recommendations:
* TI-89, TI-92+ or Voyage 200 are fast enough to take advantage of this.
* Be careful dbus I/O high is 3.3v.
* Edit Makefile and board pcf to suit your board and preferences.
* Connect 2.5mm jack sleeve to GND rather than o_sleeve.
* Use pullup resistors on dbus tip/ring.

Thanks:
* Tim Singer/Romain Liévin for TI-73...V200 protocol guide.
