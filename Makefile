board = icestick
include boards/$(board)/Makefile
#board dbus speed. If commented, it is up to the board Makefile.
#safe default for bad cables / slower calcs.
dbusMHz = 2
#override uart rate.
# uartrate = 57600
#disable hwflow by uncommenting to undefine, overriding board Makefile.
# undefine hwflow
#override buffer sizes if desired
# uartrxbufpow2 = 9
# uarttxbufpow2 = 9
nextpnr_flags = #-r
iverilog_flags = -g2005 -Wall
icetime_flags = -d $(chip) -P $(package)
synth_macros = -D$(board)=board -Duartrate=$(uartrate) -Dclock=$(MHz)000000 -Duartrxbufpow2=$(uartrxbufpow2) -Duarttxbufpow2=$(uarttxbufpow2)
ifdef dbusMHz
synth_macros += -Ddbusclock=$(dbusMHz)000000
endif
ifdef uartmirror
synth_macros += -Duartmirror=y
endif
ifdef hwflow
synth_macros += -Dhwflow=y
endif
ifdef invleds
synth_macros += -Dinvleds=y
endif
nextpnr_target = --$(chip) --package $(package)
yosys_synthflags = -abc2
.PHONY: all
all: banner main.iv main.json main.txt icetime.json main.bin
.PHONY: banner
banner:
	@echo "***** dbus_ti_link_uart_verilog"
	@echo "***** Roc Vallès i Domènech"
	@echo "board: $(board)"
	@echo "UART rate: $(uartrate)"
ifdef hwflow
	@echo "UART flow control: RTS/CTS enabled."
else
	@echo "UART flow control: Disabled."
endif
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
	icetime main.txt -c $(MHz) -j icetime.json $(icetime_flags)
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
ifeq ($(programmer),icesprog)
	icesprog -w main.bin
endif
ifeq ($(programmer),icecore)
	stty -F /dev/ttyACM0 raw
	cat main.bin >/dev/ttyACM0
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
ifeq ($(programmer),icesprog)
	icesprog -p
endif
