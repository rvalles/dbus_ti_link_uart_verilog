board = icestick
include boards/$(board)/Makefile
uartrate = 115200
nextpnr_flags = #-r
iverilog_flags = -g2005 -Wall
icetime_flags = -d $(chip) -P $(package)
synth_macros = -Duartrate=$(uartrate) -Dclock=$(MHz)000000 -Duartrxbufpow2=$(uartrxbufpow2) -Duarttxbufpow2=$(uarttxbufpow2)
ifdef dbusMHz
synth_macros += -Ddbusclock=$(dbusMHz)000000
endif
nextpnr_target = --$(chip) --package $(package)
yosys_synthflags = -abc2
.PHONY: all
all: main.iv main.json main.txt icetime.json main.bin
main.iv: main.v uart.v clock.v ram.v dbus.v
	@echo "***** Synthetising with iverilog as sanity check..." 
	iverilog $(synth_macros) $(iverilog_flags) -s main -o main.iv main.v
main.blif main.json &: main.v uart.v clock.v ram.v dbus.v
	@echo "***** Synthetising..."
	yosys $(synth_macros) -q -l yosys.log -p "synth_ice40 -top main -blif main.blif -json main.json $(yosys_synthflags)" main.v
main.txt: main.json $(pcf)
	@echo "***** Placing and Routing..."
	nextpnr-ice40 --asc main.txt --top main --json main.json --pcf $(pcf) --freq $(MHz) --quiet --log nextpnr.log $(nextpnr_target) $(nextpnr_flags)
icetime.json: main.txt $(pcf)
	@echo "***** Timing analysis..."
	icetime main.txt -p $(pcf) -c $(MHz) -j icetime.json $(icetime_flags)
main.bin: main.txt
	@echo "***** Packing..."
	icepack main.txt main.bin
.PHONY: clean
clean:
	@echo "***** Removing build artifacts..."
	rm -f main.iv main.blif main.json main.txt main.bin icetime.json yosys.log nextpnr.log
.PHONY: prog
prog: main.bin
	@echo "***** Programming..."
ifeq ($(programmer),iceprog)
	iceprog main.bin
endif
ifeq ($(programmer),tinyprog)
	tinyprog --pyserial -p main.bin
endif
.PHONY: warmboot
warmboot:
	@echo "***** Warm boot..."
ifeq ($(programmer),iceprog)
	iceprog -t
endif
ifeq ($(programmer),tinyprog)
	tinyprog -b
endif
