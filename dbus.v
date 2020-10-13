`default_nettype none
`define VOTE3(a,b,c) (a&&b)||(b&&c)||(a&&c)
module dbus #(
	parameter c_TIMEOUT=20000,
	parameter c_CLOCKFREQ=4000000)
	(
		input i_clock,
		input [7:0] i_data,
		input i_enable,
		input i_read,
		output [7:0] o_data,
		output o_busy,
		output o_avail,
		output o_drive,
		output o_receiving,
		output o_reset,
		inout io_tip, //0
		inout io_ring //1
	);
	parameter c_TIMERSIZE = $clog2(c_TIMEOUT);
	parameter c_TIMERTICKS = (c_CLOCKFREQ/10000);
	parameter c_TIMERFASTSIZE = $clog2(c_TIMERTICKS);
	reg [0:7] r_OUTPUTMSG;
	reg [7:0] r_INPUTMSG;
	reg [0:7] r_DATA;
	reg [3:0] r_POS;
	reg r_ENABLE = 1'b0;
	reg r_BUSY = 1'b0;
	reg r_GETBIT = 1'b0;
	reg r_SENDBIT = 1'b0;
	reg r_WAITACK = 1'b0;
	reg r_WAITIDLE = 1'b0;
	reg r_TMPTIP = 1'b0;
	reg r_TMPRING = 1'b0;
	reg r_TMPTIP0 = 1'b0;
	reg r_TMPRING0 = 1'b0;
	reg r_TMPTIP1 = 1'b0;
	reg r_TMPRING1 = 1'b0;
	reg r_TMPTIP2 = 1'b0;
	reg r_TMPRING2 = 1'b0;
	reg r_READTIP = 1'b0;
	reg r_READRING = 1'b0;
	reg r_BIT;
	reg r_RING = 1'b0;
	reg r_TIP = 1'b0;
	reg r_RECEIVING = 1'b0;
	reg r_RECVBIT = 1'b0;
	reg r_SETBIT = 1'b0;
	reg r_WAITACKACK = 1'b0;
	reg r_WAITACKRELEASE = 1'b0;
	reg r_AVAIL = 1'b0;
	reg r_OVERFLOW = 1'b0;
	reg r_READ = 1'b0;
	reg r_RESET = 1'b0;
	reg r_RESETDORESET = 1'b0;
	reg r_RESETWAITIDLE = 1'b0;
	reg r_RESETSENDERROR = 1'b0;
	reg r_TIMERENABLE = 1'b0;
	reg r_TIMERINTERNALENABLED = 1'b0;
	reg r_TIMERINTERNALTRIGGER = 1'b0;
	reg r_TIMERTRIGGERED = 1'b0;
	reg r_TIMERINTERNALENABLE = 1'b0;
	reg [c_TIMERSIZE-1:0] r_TIMER = 0;
	reg [c_TIMERSIZE-1:0] r_TIMERINTERNALCOUNT = 0;
	reg [c_TIMERSIZE-1:0] r_TIMERINTERNAL = 0;
	reg [c_TIMERFASTSIZE-1:0] r_TIMERINTERNALFAST = 0;
	always @ (posedge i_clock)
		begin
			r_TIMERINTERNALENABLE <= r_TIMERENABLE;
			r_TIMERINTERNAL <= r_TIMER;
			if (r_TIMERINTERNALFAST == c_TIMERTICKS)
				r_TIMERINTERNALFAST <= 0;
			else
				r_TIMERINTERNALFAST <= r_TIMERINTERNALFAST+1;
			if (r_TIMERINTERNALENABLED)
				begin
					if (!r_TIMERINTERNALENABLE)
						begin
							r_TIMERINTERNALENABLED <= 1'b0;
							r_TIMERINTERNALTRIGGER <= 1'b0;
						end
					else
						begin
							if (r_TIMERINTERNALCOUNT == 0)
								r_TIMERINTERNALTRIGGER <= 1'b1;
							else
								if (r_TIMERINTERNALFAST == 0)
									r_TIMERINTERNALCOUNT <= r_TIMERINTERNALCOUNT-1;
						end
				end
			else if (r_TIMERINTERNALENABLE)
				begin
					r_TIMERINTERNALCOUNT <= r_TIMERINTERNAL;
					r_TIMERINTERNALENABLED <= 1'b1;
				end
		end
	always @ (posedge i_clock)
		begin
			//Timeout: Signal error and reset.
			if (r_TIMERTRIGGERED && !r_RESET)
				begin
					r_RESET <= 1'b1;
					r_TIMERENABLE <= 1'b0;
					r_RESETDORESET <= 1'b1;
				end
			if (r_RESETDORESET && !r_TIMERTRIGGERED)
				begin
					r_RESETDORESET <= 1'b0;
					r_RESETSENDERROR <= 1'b1;
					r_TIMER <= 13; //at least 300µs
					r_TIMERENABLE <= 1'b1;
					r_TIP <= 1'b1;
					r_RING <= 1'b1;
					r_BUSY <= 1'b1;
					//actually reset to sane state
					r_RECEIVING = 1'b0;
					r_RECVBIT = 1'b0;
					r_SETBIT = 1'b0;
					r_WAITACKACK = 1'b0;
					r_WAITACKRELEASE = 1'b0;
					r_AVAIL = 1'b0;
					r_OVERFLOW = 1'b0;
				end
			if (r_RESETSENDERROR && r_TIMERTRIGGERED)
				begin
					r_RESETSENDERROR <= 1'b0;
					r_RESETWAITIDLE <= 1'b1;
					r_TIMERENABLE <= 1'b0;
					r_TIP <= 1'b0;
					r_RING <= 1'b0;
				end
			if (r_RESETWAITIDLE && !r_TIMERTRIGGERED && !r_READRING && !r_READTIP)
				begin
					r_RESETWAITIDLE <= 1'b0;
					r_RESET <= 1'b0;
					r_BUSY = 1'b0;
				end
			if (!r_RESET)
				begin
					//TX
					if (!r_BUSY && r_ENABLE && !r_READTIP && !r_READRING)
						begin
							r_BUSY <= 1'b1;
							r_GETBIT <= 1'b1;
							r_POS <= 0;
							r_OUTPUTMSG <= i_data;
						end
					if (r_GETBIT)
						if (r_POS == 8)
							begin
								r_BUSY <= 1'b0;
								r_GETBIT <= 1'b0;
							end
						else
							begin
								r_OUTPUTMSG <= r_OUTPUTMSG>>1;
								r_POS <= r_POS+1;
								r_BIT <= r_OUTPUTMSG[7];
								r_GETBIT <= 1'b0;
								r_SENDBIT <= 1'b1;
							end
					if (r_SENDBIT)
						begin
							if (r_BIT)
								r_RING <= 1'b1;
							else
								r_TIP <= 1'b1;
							r_SENDBIT <= 1'b0;
							r_WAITACK <= 1'b1;
							r_TIMER <= c_TIMEOUT;
							r_TIMERENABLE <= 1'b1;
						end
					if (r_WAITACK)
						if (r_BIT && r_READTIP)
							begin
								r_RING <= 1'b0;
								r_WAITACK <= 1'b0;
								r_WAITIDLE <= 1'b1;
								r_TIMERENABLE <= 1'b0;
							end
						else if (!r_BIT && r_READRING)
							begin
								r_TIP <= 1'b0;
								r_WAITACK <= 1'b0;
								r_WAITIDLE <= 1'b1;
								r_TIMERENABLE <= 1'b0;
							end
					if (r_WAITIDLE)
						if (r_BIT && !r_READTIP)
							begin
								r_RING <= 1'b0;
								r_WAITIDLE <= 1'b0;
								r_GETBIT <= 1'b1;
							end
						else if (!r_BIT && !r_READRING)
							begin
								r_TIP <= 1'b0;
								r_WAITIDLE <= 1'b0;
								r_GETBIT <= 1'b1;
							end
					//RX
					if (r_READ)
						begin
							r_AVAIL <= 1'b0;
							r_OVERFLOW <= 1'b0;
						end
					if (!r_BUSY && !r_AVAIL && (r_READTIP || r_READRING))
						begin
							r_RECEIVING <= 1'b1;
							r_RECVBIT <= 1'b1;
							r_BUSY <= 1'b1;
							r_POS <= 0;
							r_INPUTMSG <= 0;
						end
					if (r_RECVBIT)
						begin
							if (r_READRING && !r_READTIP)
								begin
									r_BIT <= 1'b1;
									r_RECVBIT <= 1'b0;
									r_SETBIT <= 1'b1;
									r_TIP <= 1'b1;
								end
							if (r_READTIP && !r_READRING)
								begin
									r_BIT <= 1'b0;
									r_RECVBIT <= 1'b0;
									r_SETBIT <= 1'b1;
									r_RING <= 1'b1;
								end
						end
					if (r_SETBIT)
						begin
							r_SETBIT <= 1'b0;
							r_INPUTMSG <= {r_BIT, r_INPUTMSG[7:1]};
							r_POS <= r_POS+1;
							r_WAITACKACK <= 1'b1;
							r_TIMER <= c_TIMEOUT;
							r_TIMERENABLE <= 1'b1;
						end
					if (r_WAITACKACK && ((r_RING && !r_READTIP) || (r_TIP && !r_READRING)))
						begin
							r_WAITACKACK <= 1'b0;
							r_WAITACKRELEASE <=  1'b1;
							r_TIP <= 1'b0;
							r_RING <= 1'b0;
						end
					if (r_WAITACKRELEASE && !r_READRING && !r_READTIP)
						begin
							r_WAITACKRELEASE <= 1'b0;
							r_TIMERENABLE <= 1'b0;
							if (r_POS == 8)
								begin
									r_DATA <= r_INPUTMSG;
									r_AVAIL <= 1'b1;
									r_BUSY <= 1'b0;
									r_RECEIVING <= 1'b0;
									if (r_AVAIL || i_read)
										r_OVERFLOW <= 1'b1;
								end
							else
								r_RECVBIT <= 1'b1;
						end
				end
			r_ENABLE <= i_enable;
			r_TMPTIP <= !io_tip;
			r_TMPRING <= !io_ring;
			r_TMPTIP0 <= r_TMPTIP;
			r_TMPRING0 <= r_TMPRING;
			r_TMPTIP1 <= r_TMPTIP0;
			r_TMPRING1 <= r_TMPRING0;
			r_TMPTIP2 <= r_TMPTIP1;
			r_TMPRING2 <= r_TMPRING1;
			r_READTIP <= `VOTE3(r_TMPTIP0, r_TMPTIP1, r_TMPTIP2);
			r_READRING <= `VOTE3(r_TMPRING0, r_TMPRING1, r_TMPRING2);
			r_READ <= i_read;
			r_TIMERTRIGGERED <= r_TIMERINTERNALTRIGGER;
		end
	assign o_busy = r_BUSY;
	assign io_ring = r_RING ? 1'b0 : 1'bZ;
	assign io_tip = r_TIP ? 1'b0 : 1'bZ;
	assign o_avail = r_AVAIL;
	assign o_drive = r_TIP || r_RING;
	assign o_receiving = r_RECEIVING;
	assign o_data = r_DATA;
	assign o_reset = r_RESET;
endmodule
