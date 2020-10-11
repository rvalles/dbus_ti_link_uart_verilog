`include "clock.v"
`include "uart.v"
`include "dbus.v"
`default_nettype none
module uart_dbus_bridge #(
	parameter c_RXADDRWIDTH = 13,
	parameter c_TXADDRWIDTH = 3)
	(
		input i_clock,
		input i_rxclock,
		input i_txclock,
		input i_rx,
		output o_tx,
		inout io_tip,
		inout io_ring,
		output o_full, o_busy, o_drive, o_receiving
	);
	wire w_davail, w_dbusy;
	wire w_avail, w_txbusy, w_rxfull, w_txfull;
	wire [7:0] w_rxdata;
	wire [7:0] w_ddata;
	reg [7:0] r_DATA;
	reg [7:0] r_DDATA;
	reg r_READ = 1'b0;
	reg r_DREAD = 1'b0;
	reg r_AVAIL = 1'b0;
	reg r_DAVAIL = 1'b0;
	reg r_DBUSY = 1'b1;
	reg r_TXBUSY = 1'b1;
	reg r_TXFULL = 1'b1;
	//RX to DBUS
	always @ (posedge i_clock)
		begin
			if (r_AVAIL && !r_READ && !r_DBUSY)
				begin
					r_READ <= 1'b1;
					r_DATA <= w_rxdata;
				end
			if (r_READ && !r_AVAIL)
				r_READ <= 1'b0;
			r_AVAIL <= w_avail;
			r_DBUSY <= w_dbusy;
		end
	//DBUS to TX
	always @ (posedge i_clock)
		begin
			if (r_DAVAIL && !r_DREAD && !r_TXBUSY)
				begin
					r_DREAD <= 1'b1;
					r_DDATA <= w_ddata;
				end
			if (r_DREAD && !r_DAVAIL)
				r_DREAD <= 1'b0;
			r_DAVAIL <= w_davail;
			r_TXBUSY <= w_txbusy;
			r_TXFULL <= w_txfull;
		end
	assign o_busy = w_dbusy;
	assign o_full = w_rxfull;
	uart_rx_3x_fifo #(
		.c_ADDRWIDTH (c_RXADDRWIDTH)
	) myuart_rx(
		.i_clock (i_clock),
		.i_uartclock (i_rxclock),
		.i_rx (i_rx),
		.i_read (r_READ),
		.o_avail (w_avail),
		.o_data (w_rxdata),
		.o_full (w_rxfull)
		);
	uart_tx_fifo #(
		.c_ADDRWIDTH (c_TXADDRWIDTH)
	) myuart_tx(
		.i_clock (i_clock),
		.i_uartclock (i_txclock),
		.i_data (r_DDATA),
		.i_enable (r_DREAD),
		.o_tx (o_tx),
		.o_busy (w_txbusy),
		.o_full (w_txfull)
		);
	dbus mybus(
		.i_clock (i_clock),
		.i_data (r_DATA),
		.i_enable (r_READ),
		.i_read (r_DREAD),
		.io_tip (io_tip),
		.io_ring (io_ring),
		.o_data (w_ddata),
		.o_avail (w_davail),
		.o_busy (w_dbusy),
		.o_drive (o_drive),
		.o_receiving (o_receiving)
		);
endmodule
module main (
		input i_clock, //main clock input
		input i_rx, //uart RX
		output o_tx, //uart TX
		output o_cts, //uart RTS
`ifdef uartmirror
		output o_auxrx, o_auxtx, o_auxcts, //uart mirror for debug
`endif
		output o_sleeve, //dbus sleeve. Permanently driven LOW.
		output o_clock, //debug uart clock output
		output o_full, //debug uart buffer full
		output o_busy, //debug dbus is busy
		output o_drive, //debug dbus driving the bus
		output o_receiving, //debug dbus receiving
		inout io_tip, //dbus tip
		inout io_ring //dbus ring
	);
	wire w_uartclock, w_uart3xclock, w_uartfull;
	freqgen #(
		.c_IFREQ (`clock),
		.c_OFREQ (`uartrate)
	) uartclock (
		.i_clock (i_clock),
		.o_clock (w_uartclock)
		);
	freqgen #(
		.c_IFREQ (`clock),
		.c_OFREQ (`uartrate*3)
	) uart3xclock (
		.i_clock (i_clock),
		.o_clock (w_uart3xclock)
		);
`ifdef dbusclock
	wire w_dbusclock;
	freqgen #(
		.c_IFREQ (`clock),
		.c_OFREQ (`dbusclock)
	) dbusclock (
		.i_clock (i_clock),
		.o_clock (w_dbusclock)
		);
`endif
	wire w_rx, w_tx, w_cts;
	uart_dbus_bridge #(
		.c_RXADDRWIDTH(`uartrxbufpow2),
		.c_TXADDRWIDTH(`uarttxbufpow2)
	) mybridge(
`ifdef dbusclock
		.i_clock (w_dbusclock),
`else
		.i_clock (i_clock),
`endif
		.i_rxclock (w_uart3xclock),
		.i_rx (w_rx),
		.i_txclock (w_uartclock),
		.o_tx (w_tx),
		.io_tip (io_tip),
		.io_ring (io_ring),
		.o_busy (o_busy),
		.o_drive (o_drive),
		.o_receiving (o_receiving),
		.o_full (w_uartfull)
		);
	assign o_full = w_uartfull;
	assign o_cts = w_uartfull;
	assign o_clock = w_uartclock;
	assign o_sleeve = 1'b0;
	assign w_rx = i_rx;
	assign o_tx = w_tx;
`ifdef uartmirror
	assign o_auxrx = w_rx;
	assign o_auxtx = w_tx;
	assign o_auxcts = w_uartfull;
`endif
endmodule
