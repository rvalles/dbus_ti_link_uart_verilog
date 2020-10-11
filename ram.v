//ram_dualport: 2-port ram. Should infer an SB_RAM512x8 EBR.
//Adapted from TN1250, Memory Usage Guide for iCE40 Devices.
module ram_dualport_infer #(
	parameter c_ADDRWIDTH = 9,
	parameter c_DATAWIDTH = 8)
	(
		input [c_DATAWIDTH-1:0] i_data,
		input i_wenable,
		input [c_ADDRWIDTH-1:0] i_waddr,
		input i_wclk,
		input [c_ADDRWIDTH-1:0] i_raddr,
		input i_rclk,
		output reg [c_DATAWIDTH-1:0] o_data
	);
	reg [c_DATAWIDTH-1:0] r_MEM [(1<<c_ADDRWIDTH)-1:0];
	always @(posedge i_wclk) //Write memory.
		if (i_wenable)
			r_MEM[i_waddr] <= i_data; //Using write address bus.
	always @(posedge i_rclk) //Read memory.
		o_data <= r_MEM[i_raddr]; //Using read address bus.
endmodule
module ram_fifo #(
	parameter c_ADDRWIDTH = 9, //Has to be 3+ for nearfull to work
	parameter c_DATAWIDTH = 8)
	(
		input i_clock,
		input i_writeen,
		input [c_DATAWIDTH-1:0] i_data,
		input i_readen,
		output [c_DATAWIDTH-1:0] o_data,
		output o_full,
		output o_nearfull,
		output o_empty
	);
	reg [c_ADDRWIDTH-1:0] r_WADDR = 0;
	reg [c_ADDRWIDTH-1:0] r_RADDR = 0;
	wire [c_ADDRWIDTH-1:0] w_nextwaddr;
	//wire [c_ADDRWIDTH-1:0] w_next2waddr;
	//wire [c_ADDRWIDTH-1:0] w_next3waddr;
	//wire [c_ADDRWIDTH-1:0] w_next4waddr;
	wire [c_ADDRWIDTH-1:0] w_nextraddr;
	wire [c_DATAWIDTH-1:0] w_wdata;
	wire [c_DATAWIDTH-1:0] w_rdata;
	wire w_full, w_nearfull, w_empty, w_fastempty;
	reg [c_DATAWIDTH-1:0] r_RDATA;
	reg r_EMPTY = 1'b1;
	reg r_FULL = 1'b0;
	always @(posedge i_clock)
		if (i_writeen && !r_FULL)
			r_WADDR <= r_WADDR+1;
	always @(posedge i_clock)
		r_FULL <= w_full;
	always @(posedge i_clock)
		if (i_readen && !r_EMPTY)
			r_RADDR <= r_RADDR+1;
	always @(posedge i_clock)
		if (!r_EMPTY && i_readen)
			r_EMPTY <= w_fastempty;
		else
			r_EMPTY <= w_empty;
	assign o_full = w_full;
	assign o_nearfull= w_nearfull;
	assign o_empty = r_EMPTY;
	assign o_data = w_wdata;
	assign w_nextwaddr = r_WADDR+1;
	assign w_full = (w_nextwaddr == r_RADDR);
	//assign w_next2waddr = r_WADDR+2;
	//assign w_next3waddr = r_WADDR+3;
	//assign w_next4waddr = r_WADDR+4;
	//assign w_nearfull = w_full || (w_next2waddr == r_RADDR) || (w_next3waddr == r_RADDR) || (w_next4waddr == r_RADDR);
	assign w_nearfull = !w_empty && ((r_RADDR - r_WADDR) < (1<<(c_ADDRWIDTH-2)));
	assign w_nextraddr = r_RADDR+1;
	assign w_empty = (r_RADDR == r_WADDR);
	assign w_fastempty = (w_nextraddr == r_WADDR);
	ram_dualport_infer #(
		.c_ADDRWIDTH (c_ADDRWIDTH),
		.c_DATAWIDTH (c_DATAWIDTH)
	) myram (
		.i_data (i_data),
		.i_wenable (i_writeen),
		.i_waddr (w_nextwaddr),
		.i_wclk (i_clock),
		.i_raddr (w_nextraddr),
		.i_rclk (i_clock),
		.o_data (w_wdata)
	);
endmodule
