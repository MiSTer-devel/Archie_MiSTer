/*	
	Copyright (c) 2013-2014, Stephen J. Leary
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:
		 * Redistributions of source code must retain the above copyright
			notice, this list of conditions and the following disclaimer.
		 * Redistributions in binary form must reproduce the above copyright
			notice, this list of conditions and the following disclaimer in the
			documentation and/or other materials provided with the distribution.
		 * Neither the name of the Stephen J. Leary nor the
			names of its contributors may be used to endorse or promote products
			derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL STEPHEN J. LEARY BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
*/

module sdram
(
	// interface to the MT48LC16M16 chip
	input            sd_clk,	  // sdram is accessed at 128MHz
	input            sd_rst,	  // reset the sdram controller.
	output           sd_cke,	  // clock enable.
	inout  reg[15:0] sd_dq,		  // 16 bit bidirectional data bus
	output reg[12:0] sd_addr,	  // 13 bit multiplexed address bus
	output    [1:0]  sd_dqm,	  // two byte masks
	output reg[1:0]  sd_ba,		  // two banks
	output           sd_cs_n,	  // a single chip select
	output           sd_we_n,	  // write enable
	output           sd_ras_n,	  // row address select
	output           sd_cas_n,	  // columns address select
	output reg       sd_ready,	  // sd ready.
	output           sd_clk_out,

	// cpu/chipset interface

	input            wb_clk,     // 32MHz chipset clock to which sdram state machine is synchonized	
	input     [31:0] wb_dat_i,	// data input from chipset/cpu
	output reg[31:0] wb_dat_o = 0,	// data output to chipset/cpu
	output reg       wb_ack = 0, 
	input     [23:2] wb_adr,
	input      [3:0] wb_sel,		// 
	input      [2:0] wb_cti,		// cycle type. 
	input            wb_stb, 	//	
	input            wb_cyc, 	// cpu/chipset requests cycle
	input            wb_we   	// cpu/chipset requests write
);

localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 3 cycles@128MHz
localparam BURST_LENGTH   = 3'b011; // 000=1, 001=2, 010=4, 011=8, 111 = continuous.
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write
localparam RFC_DELAY      = 4'd7;   // tRFC=66ns -> 9 cycles@128MHz

// all possible commands
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

reg  [8:0] reset = 0;
reg [15:0] sd_dat[8]; // data output to chipset/cpu

reg        sd_done = 1'b0;
reg  [3:0] sd_cmd;   // current command sent to sd ram

reg  [9:0] sd_refresh = 10'd0;
reg        sd_auto_refresh = 1'b0; 
wire       sd_req = wb_stb & wb_cyc & ~wb_ack;
wire       sd_reading = wb_stb & wb_cyc & ~wb_we;
wire       sd_writing = wb_stb & wb_cyc & wb_we;

localparam CYCLE_IDLE       = 4'd0;
localparam CYCLE_RAS_START  = CYCLE_IDLE;
localparam CYCLE_RFSH_START = CYCLE_RAS_START; 
localparam CYCLE_CAS0 		 = CYCLE_RAS_START  + RASCAS_DELAY;
localparam CYCLE_CAS1       = CYCLE_CAS0 + 4'd1;		
localparam CYCLE_CAS2       = CYCLE_CAS1 + 4'd1;		
localparam CYCLE_CAS3       = CYCLE_CAS2 + 4'd1;				
localparam CYCLE_READ0      = CYCLE_CAS0 + CAS_LATENCY + 4'd2;
localparam CYCLE_READ1      = CYCLE_READ0+ 1'd1;
localparam CYCLE_READ2      = CYCLE_READ1+ 1'd1;
localparam CYCLE_READ3      = CYCLE_READ2+ 1'd1;
localparam CYCLE_READ4      = CYCLE_READ3+ 1'd1;
localparam CYCLE_READ5      = CYCLE_READ4+ 1'd1;
localparam CYCLE_READ6      = CYCLE_READ5+ 1'd1;
localparam CYCLE_READ7      = CYCLE_READ6+ 1'd1;
localparam CYCLE_RFSH_END   = CYCLE_RFSH_START + RFC_DELAY; 

localparam RAM_CLK          = 126000000;
localparam REFRESH_PERIOD   = (RAM_CLK / (16 * 8192));

always @(posedge sd_clk) begin 
	reg        sd_reqD, sd_reqD2;
	reg        sd_newreq;
	reg  [3:0] sd_cycle = CYCLE_IDLE;
	reg  [2:0] word;
	reg [15:0] sd_dq_reg;

	sd_dq <= 16'bZZZZZZZZZZZZZZZZ;
	sd_cmd <= CMD_NOP;
	
	sd_dq_reg <= sd_dq;
	
	sd_reqD <= sd_req;
	if(~sd_reqD & sd_req) sd_newreq <= 1;

	// count while the cycle is active
	if(sd_cycle != CYCLE_IDLE) sd_cycle <= sd_cycle + 3'd1;
	sd_refresh <= sd_refresh + 9'd1;

	if (sd_rst) reset <= 0;
	else begin
		if (~&reset) begin
			sd_ready <= 0;
			sd_ba    <= 0;
			word     <= 0;
			sd_cycle <= CYCLE_IDLE;
			sd_auto_refresh <= 0;
			sd_refresh <= 0;

			reset <= reset + 1'd1;

			if(reset == 32 || reset == 96) begin
				sd_cmd  <= CMD_PRECHARGE;
				sd_addr <= 13'b0010000000000; // precharge all banks
			end

			if(reset == 208) begin
				sd_cmd  <= CMD_LOAD_MODE;
				sd_addr <= MODE;
			end
		end
		else begin
			sd_ready <= 1;

			if(word) begin
				word <= word + 1'd1;
				sd_dat[word] <= sd_dq_reg;
			end

			if (sd_auto_refresh) begin 
				if(sd_cycle >= CYCLE_RFSH_END) begin 
					sd_auto_refresh <= 0;
					sd_cycle <= CYCLE_IDLE;
				end
			end
			else begin
				case(sd_cycle)
				CYCLE_IDLE: begin
					if (sd_refresh > REFRESH_PERIOD) begin 
						// this is the auto refresh code.
						// it kicks in so that 8192 auto refreshes are 
						// issued in a 64ms period. Other bus operations 
						// are stalled during this period.
						sd_auto_refresh<= 1;
						sd_refresh		<= 0;
						sd_cmd	      <= CMD_AUTO_REFRESH;
						sd_cycle       <= sd_cycle + 3'd1;
					end
					else if(sd_newreq) begin
						sd_cmd 	      <= CMD_ACTIVE;
						sd_addr	      <= wb_adr[21:10];
						sd_ba 	      <= wb_adr[23:22];
						sd_cycle       <= sd_cycle + 3'd1;
					end
				end

				// this is the first CAS cycle
				CYCLE_CAS0: begin 
					// always, always read on a 32bit boundary and completely ignore the lsb of wb_adr.
					sd_addr           <= { 4'b0000, wb_adr[9:2], 1'b0 };  // no auto precharge

					if (sd_reading) begin 
						sd_cmd         <= CMD_READ;
						sd_addr[10]	   <= 1;        // auto precharge
					end else if (sd_writing) begin 
						sd_cmd         <= CMD_WRITE;
						sd_addr[12:11] <= ~wb_sel[1:0];
						sd_dq	         <= wb_dat_i[15:0];
					end
				end

				CYCLE_CAS1: begin 
					// now we access the second part of the 32 bit location.
					if (sd_writing) begin 
						sd_addr[10]    <= 1;        // auto precharge
						sd_addr[0]     <= 1;
						sd_cmd         <= CMD_WRITE;
						sd_addr[12:11] <= ~wb_sel[3:2];
						sd_done        <= ~sd_done;
						sd_newreq      <= 0;
						sd_dq          <= wb_dat_i[31:16];
					end
				end

				CYCLE_READ0: begin 
					if (sd_reading) begin 
						sd_dat[0]      <= sd_dq_reg;
						word           <= 1;
					end else begin
						if (sd_writing) sd_cycle <= CYCLE_IDLE;
					end 
				end
				CYCLE_READ1: begin 
					sd_done           <= ~sd_done;
					sd_newreq         <= 0;
				end

				CYCLE_READ5: begin 
					sd_cycle          <= CYCLE_IDLE;
				end
				endcase
			end
		end
	end
end

always @(posedge wb_clk) begin 
	reg sd_doneD;
	reg [1:0] word;
	
	sd_doneD <= sd_done;
	wb_ack	<= 0;

	if(word) word <= word + 1'd1;

	if (wb_stb & wb_cyc) begin 
		if ((sd_done ^ sd_doneD) & ~wb_ack) begin 
			wb_dat_o <= {sd_dat[1],sd_dat[0]};
			word     <= ~wb_cti[2] & (wb_cti[1] ^ wb_cti[0]); // burst constant/incremental
			wb_ack	<= 1;
		end

		if (word) begin 
			wb_dat_o <= {sd_dat[{word,1'b1}],sd_dat[{word,1'b0}]};
			wb_ack   <= 1;
		end
	end
	else begin
		word <= 0;
	end
end

// drive control signals according to current command
assign sd_cke   = 1;
assign sd_cs_n  = 0;
assign sd_ras_n = sd_cmd[2];
assign sd_cas_n = sd_cmd[1];
assign sd_we_n  = sd_cmd[0];
assign sd_dqm   = sd_addr[12:11];

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(sd_clk),
	.dataout(sd_clk_out),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

endmodule
