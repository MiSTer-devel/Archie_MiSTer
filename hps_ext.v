//
// hps_ext for Archie
//
// Copyright (c) 2020 Alexey Melnikov
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
///////////////////////////////////////////////////////////////////////

module hps_ext
(
	input             clk_sys,
	inout      [35:0] EXT_BUS,

	input       [7:0] kbd_out_data,
	input             kbd_out_strobe,
	output reg  [7:0] kbd_in_data,
	output reg        kbd_in_strobe
);

assign EXT_BUS[15:0] = io_dout;
wire [15:0] io_din = EXT_BUS[31:16];
assign EXT_BUS[32] = dout_en;
wire io_strobe = EXT_BUS[33];
wire io_enable = EXT_BUS[34];

localparam EXT_CMD_MIN = 4;
localparam EXT_CMD_MAX = 5;

reg [15:0] io_dout;
reg        dout_en = 0;
reg  [3:0] byte_cnt;

always@(posedge clk_sys) begin
	reg [15:0] cmd;
	reg  old_out_strobe = 0;
	reg  kbd_out_data_available = 0;

	kbd_in_strobe <= 0;
	old_out_strobe <= kbd_out_strobe;
	if(~old_out_strobe && kbd_out_strobe) kbd_out_data_available <= 1;

	if(~io_enable) begin
		byte_cnt <= 0;
		io_dout <= 0;
		dout_en <= 0;
	end else begin
		if(io_strobe) begin

			io_dout <= 0;
			if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;

			if(byte_cnt == 0) begin
				cmd <= io_din;
				dout_en <= (io_din >= EXT_CMD_MIN && io_din <= EXT_CMD_MAX);
			end else begin
				case(cmd)
					'h04: begin
							if(byte_cnt == 1) begin
								io_dout[7:0] <= { 4'ha, 3'b000, kbd_out_data_available };
								kbd_out_data_available <= 0;
							end else begin
								io_dout[7:0] <= kbd_out_data;
							end
						end

					'h05: begin
							if(byte_cnt == 1) kbd_in_strobe <= 1;
							kbd_in_data <= io_din[7:0];
						end
					default: ;
				endcase
			end
		end
	end
end

endmodule
