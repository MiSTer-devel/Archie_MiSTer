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
	output reg        kbd_in_strobe,
	
	input       [7:0] cmos_cnt,

	input      [15:0] ide_din,
	output reg [15:0] ide_dout,
	output reg  [4:0] ide_addr,
	output reg        ide_rd,
	output reg        ide_wr,
	input       [5:0] ide_req
);

assign EXT_BUS[15:0] = io_dout;
wire [15:0] io_din = EXT_BUS[31:16];
assign EXT_BUS[32] = io_dout_en;
wire io_strobe = EXT_BUS[33];
wire io_enable = EXT_BUS[34] | fp_enable;
wire fp_enable = EXT_BUS[35];

localparam EXT_CMD_MIN = 4;
localparam EXT_CMD_MAX = 5;
localparam EXT_CMD_MIN2= 'h61;
localparam EXT_CMD_MAX2= 'h63;

reg [15:0] io_dout;
reg        io_dout_en;
always@(posedge clk_sys) begin
	reg [7:0] cmd;
	reg       ide_cs = 0;
	reg [3:0] byte_cnt;
	reg       old_out_strobe = 0;
	reg       kbd_out_data_available = 0;

	{ide_rd, ide_wr} <= 0;
	if((ide_rd | ide_wr) & ~&ide_addr[3:0]) ide_addr <= ide_addr + 1'd1;

	kbd_in_strobe <= 0;
	old_out_strobe <= kbd_out_strobe;
	if(~old_out_strobe && kbd_out_strobe) kbd_out_data_available <= 1;

	if(~io_enable) begin
		byte_cnt <= 0;
		ide_cs <= 0;
		io_dout <= 0;
		io_dout_en <= 0;
	end else begin
		if(io_strobe) begin

			io_dout <= 0;
			if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;
			ide_dout <= io_din;
			if(byte_cnt == 1) begin
				ide_addr <= {io_din[8],io_din[3:0]};
				ide_cs   <= (io_din[15:9] == 7'b1111000);
			end

			if(byte_cnt == 0) begin
				cmd <= io_din[7:0];
				io_dout_en <= fp_enable ? !io_din : ((io_din >= EXT_CMD_MIN && io_din <= EXT_CMD_MAX) || (io_din >= EXT_CMD_MIN2 && io_din <= EXT_CMD_MAX2));
				if(io_din == 'h63) io_dout <= {4'hE, 2'b00, 2'b00, 2'b00, ide_req};
				if(io_din == 'h00) io_dout <= cmos_cnt;
			end
			else begin
				case(cmd)
					'h04: if(byte_cnt == 1) begin
								io_dout[7:0] <= { 4'ha, 3'b000, kbd_out_data_available };
								kbd_out_data_available <= 0;
							end
							else begin
								io_dout[7:0] <= kbd_out_data;
							end

					'h05: begin
								if(byte_cnt == 1) kbd_in_strobe <= 1;
								kbd_in_data <= io_din[7:0];
							end

					'h61: if(byte_cnt >= 3 && ide_cs) begin
								ide_wr <= 1;
							end
	
					'h62: if(byte_cnt >= 3 && ide_cs) begin
								io_dout <= ide_din;
								ide_rd <= 1;
							end
					default: ;
				endcase
			end
		end
	end
end

endmodule
