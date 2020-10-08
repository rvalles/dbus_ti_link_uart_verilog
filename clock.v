// freqgen: Generate a clock at aproximately the specified frequency.
module freqgen #(
		parameter c_IFREQ = 12000000, //Frequency of the input clock
		parameter c_OFREQ = 300) //Frequency of the generated clock
	(
		input i_clock, //Input clock
		output o_clock //Output generated clock
	);
	parameter c_TICKS = (c_IFREQ/c_OFREQ)/2;
	parameter c_COUNTERSIZE = $clog2(c_TICKS);
	reg r_CLOCK = 1'b0;
	reg [c_COUNTERSIZE-1:0] r_COUNTER = 0;
	always @ (posedge i_clock)
		begin
			if (r_COUNTER == c_TICKS-1)
				begin
					r_CLOCK <= !r_CLOCK;
					r_COUNTER <= 0;
				end
			else
				r_COUNTER <= r_COUNTER+1;
		end
	assign o_clock = r_CLOCK;
endmodule
