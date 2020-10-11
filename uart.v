`include "ram.v"
`default_nettype none
`define VOTE3(a,b,c) (a&&b)||(b&&c)||(a&&c)
/*uart_tx_raw, unbuffered
 *It should not be used directly from a separate clock domain.
 */
module uart_tx_raw (
		input i_uartclock, //UART clock
		input [7:0] i_data, //UART data to send
		input i_enable, //UART data enable: i_data is wired
		output o_tx, //UART TX
		output o_busy //UART is busy
	);
	reg r_BUSY = 1'b0;
	reg r_OUTPUT = 1'b1;
	reg [3:0] r_OPOS;
	reg [0:7] r_OUTPUTMSG = 0;
	always @ (posedge i_uartclock)
		begin
			if (r_BUSY == 1)
				begin
					if (r_OPOS == 8)
						begin
							r_BUSY <= 1'b0;
							r_OUTPUT <= 1'b1; //stop bit
						end
					else
						begin
							r_OUTPUTMSG <= r_OUTPUTMSG>>1;
							r_OPOS <= r_OPOS+1;
							r_OUTPUT <= r_OUTPUTMSG[7];
						end
				end
			else if (i_enable == 1'b1)
				begin
					r_OUTPUTMSG <= i_data;
					r_OUTPUT <= 1'b0; //start bit
					r_OPOS <= 0;
					r_BUSY <= 1'b1;
				end
		end
	assign o_tx = r_OUTPUT;
	assign o_busy = r_BUSY;
endmodule
/*uart_tx, buffered.
 *o_busy should happen faster as buffer uses the outside clock.
 *o_busy won't be released until i_enable is.
 */
module uart_tx (
		input i_clock, //clock
		input i_uartclock, //UART clock
		input [7:0] i_data, //UART data to send
		input i_enable, //UART data enable: i_data is wired
		output o_tx, //UART TX
		output o_busy //UART is busy
	);
	reg r_ENABLE = 1'b0;
	reg r_ENABLED = 1'b0;
	reg r_BUSY = 1'b0;
	reg r_DTACK = 1'b0;
	reg [7:0] r_DATA;
	wire w_busy;
	always @ (posedge i_clock)
		begin
			if (r_ENABLE && !r_ENABLED && !r_DTACK && !r_BUSY)
				begin
					r_DATA <= i_data;
					r_ENABLED <= 1'b1;
					r_DTACK <= 1'b1;
				end
			if (r_ENABLED && r_BUSY)
				r_ENABLED <= 1'b0;
			if (r_DTACK && !r_ENABLE)
				r_DTACK <= 1'b0;
			r_ENABLE <= i_enable;
			r_BUSY <= w_busy;
		end
	assign o_busy = r_DTACK;
	uart_tx_raw myuart_tx_raw(
		.i_uartclock (i_uartclock),
		.i_data (r_DATA),
		.i_enable (r_ENABLED),
		.o_tx (o_tx),
		.o_busy (w_busy)
		);
endmodule
/*uart_tx, fifo.
 *fifo buffers writes.
 *o_busy won't be released until i_enable is.
 *o_busy sticks if the fifo is full.
 */
module uart_tx_fifo #(
	parameter c_ADDRWIDTH = 9)
	(
		input i_clock, //clock
		input i_uartclock, //UART clock
		input [7:0] i_data, //UART data to send
		input i_enable, //UART data enable: i_data is wired
		output o_tx, //UART TX
		output o_busy, //UART is busy
		output o_full, o_empty //debug
	);
	reg r_ENABLE = 1'b0;
	reg r_DTACK = 1'b0;
	reg [7:0] r_DATA;
	reg r_UARTENABLE = 1'b0;
	reg r_UARTBUSY = 1'b0;
	reg [7:0] r_UARTDATA;
	reg r_BUFRE = 1'b0;
	reg r_BUFAVAIL = 1'b0;
	reg r_BUFWE = 1'b0;
	reg r_EMPTY = 1'b1;
	reg r_FULL = 1'b0;
	wire w_uartbusy;
	wire w_full, w_empty;
	wire [7:0] w_data;
	always @ (posedge i_clock)
		begin
			if (r_ENABLE && !r_DTACK && !r_FULL)
				begin
					r_DATA <= i_data;
					r_DTACK <= 1'b1;
					r_BUFWE <= 1'b1;
				end
			if (r_BUFWE)
				r_BUFWE <= 1'b0;
			if (r_DTACK && !r_ENABLE)
				r_DTACK <= 1'b0;
			r_ENABLE <= i_enable;
			r_FULL <= w_full;
		end
	always @(posedge i_clock)
		begin
			if (!r_EMPTY && !r_UARTENABLE && !r_UARTBUSY && !r_BUFRE && !r_BUFAVAIL)
				r_BUFRE <= 1'b1;
			if (r_BUFRE)
				begin
					r_BUFRE <= 1'b0;
					r_BUFAVAIL <= 1'b1;
				end
			if (r_BUFAVAIL)
				begin
					r_UARTDATA <= w_data;
					r_UARTENABLE <= 1'b1;
					r_BUFAVAIL <= 1'b0;
				end
			if (r_UARTBUSY)
				r_UARTENABLE <= 1'b0;
			r_EMPTY <= w_empty;
			r_UARTBUSY <= w_uartbusy;
		end
	assign o_busy = (r_DTACK || r_FULL);
	assign o_full = w_full;
	assign o_empty = w_empty;
	ram_fifo #(
		.c_ADDRWIDTH (c_ADDRWIDTH),
		.c_DATAWIDTH (8)
	) txbuffer (
		.i_clock (i_clock),
		.i_data (r_DATA),
		.i_writeen (r_BUFWE),
		.i_readen (r_BUFRE),
		.o_data (w_data),
		.o_full (w_full),
		.o_empty (w_empty)
		);
	uart_tx myuart_tx(
		.i_clock (i_clock),
		.i_uartclock (i_uartclock),
		.i_data (r_UARTDATA),
		.i_enable (r_UARTENABLE),
		.o_tx (o_tx),
		.o_busy (w_uartbusy)
		);
endmodule
module uart_rx_3x_buffered (
		input i_clock, //clock
		input i_rx, //uart rx
		input i_read, //parallel data has been read
		output [7:0] o_data, //parallel data
		output o_avail, //data is available
		output o_overrun //overrun condition
	);
	reg r_AVAIL = 1'b0;
	reg r_OVERRUN = 1'b0;
	reg r_BUSY = 1'b0;
	reg r_PREV = 1'b0;
	reg r_RX = 1'b0;
	reg [3:0] r_INCOUNT;
	reg [7:0] r_DATA;
	reg [7:0] r_INPUTMSG;
	reg [1:0] r_SAMPLECOUNT;
	reg [2:0] r_SAMPLEBIT;
	always @ (posedge i_clock)
		begin
			if (r_BUSY)
				begin
					r_SAMPLEBIT <= {r_RX, r_SAMPLEBIT[2:1]};
					if (r_SAMPLECOUNT == 3) //3 bits are ready, we output
						begin
							r_SAMPLECOUNT <= 1; //1 bit (which is being sampled now) will be ready next cycle.
							r_INPUTMSG <= {`VOTE3(r_SAMPLEBIT[0], r_SAMPLEBIT[1], r_SAMPLEBIT[2]), r_INPUTMSG[7:1]};
							r_INCOUNT <= r_INCOUNT+1;
						end
					else
						r_SAMPLECOUNT <= r_SAMPLECOUNT + 1;
					if (r_INCOUNT == 8)
						begin
							r_DATA <= r_INPUTMSG;
							r_BUSY <= 1'b0;
							r_AVAIL <= 1'b1;
							if (r_AVAIL || i_read)
								r_OVERRUN <= 1'b1;
						end
				end
			else
				if (r_PREV && !r_RX) //2'b10, start bit preceded by idle or stop bit.
					begin
						r_BUSY <= 1;
						r_INCOUNT <= 15; //start bit, we'll rollover the count to 0 once start bit is over.
						r_SAMPLECOUNT <= 1;
					end
			if (i_read && r_AVAIL)
				begin
					r_AVAIL <= 1'b0;
					r_OVERRUN <= 1'b0;
				end
			r_RX <= i_rx;
			r_PREV <= r_RX;
		end
	assign o_avail = r_AVAIL;
	assign o_data = r_DATA;
	assign o_overrun = r_OVERRUN;
endmodule
module uart_rx_3x_fifo #(
	parameter c_ADDRWIDTH = 9)
	(
		input i_clock, //clock
		input i_uartclock, //UART clock
		input i_rx, //uart rx
		input i_read, //parallel data has been read
		output [7:0] o_data, //parallel data
		output o_avail, //data is available
		output o_full, //fifo full
		output o_nearfull, //fifo near full
		output o_aux //debug
	);
	reg r_RX = 1'b0;
	reg r_UARTACK = 1'b0;
	reg r_UARTNACK = 1'b0;
	reg r_UARTAVAIL = 1'b0;
	reg r_UARTOVERRUN = 1'b0;
	reg [7:0] r_UARTDATA;
	wire [7:0] w_uartdata;
	wire w_uartavail, w_uartoverrun;
	reg r_BUFACK = 1'b0;
	reg r_BUFAVAIL = 1'b0;
	reg r_BUFOVERRUN = 1'b0;
	reg [7:0] r_BUFDATA;
	wire [7:0] w_rdata;
	wire w_renable, w_full, w_nearfull, w_empty;
	reg r_BUFRE = 1'b0;
	reg r_BUFWE = 1'b0;
	reg r_EMPTY = 1'b1;
	reg r_FULL = 1'b0;
	reg r_BUFNACK = 1'b0;
	always @(posedge i_clock)
		begin
			if (r_UARTAVAIL && !r_UARTNACK)
				begin
					r_BUFWE <= 1'b1;
					r_UARTDATA <= w_uartdata;
					r_UARTACK <= 1'b1;
					r_UARTNACK <= 1'b1;
				end
			if (r_BUFWE)
				r_BUFWE <= 1'b0;
			if (!r_UARTAVAIL)
				r_UARTNACK <= 1'b0;
			r_RX <= i_rx;
			r_UARTAVAIL <= w_uartavail;
			r_UARTOVERRUN <= w_uartoverrun;
			r_FULL <= w_nearfull;
		end
	always @(posedge i_clock)
		begin
			if (!r_EMPTY && !r_BUFNACK && !r_BUFACK && !r_BUFRE)
				begin
					r_BUFNACK <= 1'b1;
					r_BUFRE <= 1'b1;
				end
			if (r_BUFRE)
				begin
					r_BUFAVAIL <= 1'b1;
					r_BUFDATA <= w_rdata;
					r_BUFRE <= 1'b0;
				end
			if (r_BUFACK)
				begin
					r_BUFNACK <= 1'b0;
					r_BUFAVAIL <= 1'b0;
				end
			r_BUFACK <= i_read;
			r_EMPTY <= w_empty;
		end
	assign o_data = r_BUFDATA;
	assign o_avail = r_BUFAVAIL;
	assign o_full = w_full;
	assign o_nearfull = w_nearfull;
	assign o_aux = r_BUFRE;
	ram_fifo #(
		.c_ADDRWIDTH (c_ADDRWIDTH),
		.c_DATAWIDTH (8)
	) rxbuffer (
		.i_clock (i_clock),
		.i_data (r_UARTDATA),
		.i_writeen (r_BUFWE),
		.i_readen (r_BUFRE),
		.o_data (w_rdata),
		.o_full (w_full),
		.o_nearfull (w_nearfull),
		.o_empty (w_empty)
		);
	uart_rx_3x_buffered myuart_rx_in(
		.i_clock (i_uartclock),
		.i_rx (r_RX),
		.i_read (r_UARTACK),
		.o_avail (w_uartavail),
		.o_data (w_uartdata),
		.o_overrun (w_uartoverrun)
		);
endmodule
