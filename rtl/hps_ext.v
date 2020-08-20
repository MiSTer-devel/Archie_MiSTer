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

	input             ide_reset,
	input             ide_req,
	output reg        ide_ack,
	output reg        ide_err,
	output reg  [8:0] ide_adr,
	output reg [15:0] ide_dat_o,
	input      [15:0] ide_dat_i,
	output reg        ide_rd,
	output reg        ide_we
);

assign EXT_BUS[15:0] = fp_dout_en ? fp_dout : io_dout;
wire [15:0] io_din = EXT_BUS[31:16];
assign EXT_BUS[32] = io_dout_en | fp_dout_en;
wire io_strobe = EXT_BUS[33];
wire io_enable = EXT_BUS[34];
wire fp_enable = EXT_BUS[35];

localparam EXT_CMD_MIN = 4;
localparam EXT_CMD_MAX = 5;

reg [15:0] io_dout;
reg        io_dout_en;
always@(posedge clk_sys) begin
	reg [7:0] cmd;
	reg [3:0] byte_cnt;
	reg       old_out_strobe = 0;
	reg       kbd_out_data_available = 0;

	kbd_in_strobe <= 0;
	old_out_strobe <= kbd_out_strobe;
	if(~old_out_strobe && kbd_out_strobe) kbd_out_data_available <= 1;

	if(~io_enable) begin
		byte_cnt <= 0;
		io_dout <= 0;
		io_dout_en <= 0;
	end else begin
		if(io_strobe) begin

			io_dout <= 0;
			if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;

			if(byte_cnt == 0) begin
				cmd <= io_din[7:0];
				io_dout_en <= (io_din >= EXT_CMD_MIN && io_din <= EXT_CMD_MAX);
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
					default: ;
				endcase
			end
		end
	end
end

localparam CMD_IDE_REGS_RD   = 8'h80;
localparam CMD_IDE_REGS_WR   = 8'h90;
localparam CMD_IDE_DATA_WR   = 8'hA0;
localparam CMD_IDE_DATA_RD   = 8'hB0;
localparam CMD_IDE_STATUS_WR = 8'hF0;

localparam STATUS_CMD = 8'h04;
localparam STATUS_DAT = 8'h08;

reg [15:0] fp_dout;
reg        fp_dout_en;
always@(posedge clk_sys) begin
	reg [7:0] cmd;
	reg [1:0] byte_cnt;
	reg       write_start = 0;
	reg       newcmd = 0;
	reg       write_req = 0;
	reg [7:0] ide_cmd;

	ide_we  <= 0;
	ide_rd  <= 0;
	ide_ack <= 0;

	if(ide_we | ide_rd) ide_adr <= ide_adr + 1'd1;
	if(ide_rd && ide_adr == 9'h107) ide_cmd <= ide_dat_i[7:0];

	if (ide_reset) begin
		newcmd <= 0;
		write_req <= 0;
		write_start <= 0;
	end

	if (ide_req) begin
		ide_err <= 0;
		newcmd <= 1;
		write_start <= write_req;
	end

	if(~ide_adr[8]) begin
		if (ide_we) newcmd <= 0;
		if (ide_rd) begin
			write_req <= 0;
			write_start <= 0;
		end
	end

	if(~fp_enable) begin
		byte_cnt <= 0;
		fp_dout <= 0;
		fp_dout_en <= 0;
	end
	else if(io_strobe) begin
		fp_dout <= 0;
		if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;

		if(!byte_cnt) begin
			cmd <= io_din[15:8];
			fp_dout_en <= (io_din[15:8] >= CMD_IDE_REGS_RD && io_din[15:8] <= CMD_IDE_STATUS_WR);
			if(!io_din) begin
				fp_dout <= {write_start ? STATUS_DAT : newcmd ? STATUS_CMD : 8'h00, cmos_cnt};
				fp_dout_en <= 1;
			end
			if(io_din[15:8] == CMD_IDE_STATUS_WR) begin
				if (io_din[7]) ide_ack <= 1;   // IDE_STATUS_END
				if (io_din[4]) newcmd  <= 0;   // IDE_STATUS_IRQ
				if (io_din[2] || ((ide_cmd == 8'h30 || ide_cmd == 8'hc5) && io_din[4] && ~io_din[7])) write_req <= 1;
				if (io_din[1]) ide_err <= 1;   // IDE_STATUS_ERR
			end
			ide_adr <= {io_din[15:8] == CMD_IDE_REGS_RD || io_din[15:8] == CMD_IDE_REGS_WR, 8'h00};
		end

		if (&byte_cnt) begin
			ide_dat_o <= io_din;
			fp_dout   <= ide_dat_i;
			ide_we    <= (cmd == CMD_IDE_REGS_WR) || (cmd == CMD_IDE_DATA_WR);
			ide_rd    <= (cmd == CMD_IDE_REGS_RD) || (cmd == CMD_IDE_DATA_RD);
		end
	end
end

endmodule
