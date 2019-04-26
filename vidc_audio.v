`timescale 1ns / 1ps
/* vidc_audio.v

 Copyright (c) 2015, Stephen J. Leary
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
// altera message_off 10030
 
module vidc_audio
(
	// cpu side - used to write registers
	input             cpu_clk, // cpu clock
	input             cpu_wr, // write to video register.
	input [31:0]      cpu_data, // data to write (data bus).

	// audio/data side of the bus
	input             aud_clk,
	input             aud_ce,
	input             aud_rst,
	input [7:0]       aud_data,
	output reg        aud_en,

	// actual audio out signal
	output reg [15:0] aud_right,
	output reg [15:0] aud_left
);
 
localparam  SOUND_SAMFREQ   = 4'b1100;
localparam  SOUND_REGISTERS = 5'b01100;   

reg [2:0] channel;
reg [2:0] vidc_sir[8];
reg [8:0] vidc_sfr;

// 1mhz pulse counter.
reg [7:0] aud_delay_count;

always @(posedge cpu_clk) begin
	if (cpu_wr) begin 

		if ({cpu_data[31:29],cpu_data[25:24]} == SOUND_REGISTERS) begin
			$display("Writing the stereo image registers: 0x%08x", cpu_data);
			vidc_sir[cpu_data[28:26] - 1'd1] <= cpu_data[2:0];
		end

		if (cpu_data[31:28] == SOUND_SAMFREQ) begin
			$display("VIDC SFR: %x", cpu_data[7:0]);
			if (cpu_data[8]) begin
				vidc_sfr <= cpu_data[8:0];
			end
		end
	end
end


function [15:0] mu2lin;
	input [7:0] value;
	begin
		mu2lin = 16'hFF << value[7:5];
		mu2lin = {4'b0000, mu2lin[15:8], 4'b0000} + ({12'd0,value[4:1]} << value[7:5]);
		if(value[0]) mu2lin = 16'd0 - mu2lin;
	end
endfunction


always @(posedge aud_clk) begin
	reg [15:0] data,al,ar;
	reg ce_d;

	ce_d <= 0;

	if (aud_rst | ~vidc_sfr[8]) begin
		channel <= 0;
		aud_en <= 0;
		aud_delay_count <= 8'hFF;
		ce_d <= 0;
		al <= 0;
		ar <= 0;
		aud_left <= 0;
		aud_right <= 0;
	end
	else if (aud_ce) begin
		aud_en <= 0;
		aud_delay_count <= aud_delay_count - 1'd1;
		if (aud_delay_count == 8'd0) begin
			ce_d <= aud_ce;
			data <= mu2lin(aud_data);
			aud_en <= 1'b1;
			aud_delay_count <= vidc_sfr[7:0];
			if(!channel) begin
				aud_right <= ar;
				aud_left  <= al;
				ar <= 0;
				al <= 0;
			end
		end
	end
	else if(ce_d) begin
		channel <= channel + 1'd1;
		case(vidc_sir[channel])
			1: begin
					al <= $signed(al) + $signed(data);
				end
			2: begin
					al <= $signed(al) + $signed(data[15:1]) + $signed(data[15:2]);
					ar <= $signed(ar) + $signed(data[15:2]);
				end
			3: begin
					al <= $signed(al) + $signed(data[15:1]) + $signed(data[15:3]);
					ar <= $signed(ar) + $signed(data[15:1]) - $signed(data[15:3]);
				end
			4: begin
					al <= $signed(al) + $signed(data[15:1]);
					ar <= $signed(ar) + $signed(data[15:1]);
				end
			5: begin
					al <= $signed(al) + $signed(data[15:1]) - $signed(data[15:3]);
					ar <= $signed(ar) + $signed(data[15:1]) + $signed(data[15:3]);
				end
			6: begin
					al <= $signed(al) + $signed(data[15:2]);
					ar <= $signed(ar) + $signed(data[15:1]) + $signed(data[15:2]);
				end
			7: begin
					ar <= $signed(ar) + $signed(data);
				end
		endcase
	end
end

endmodule
