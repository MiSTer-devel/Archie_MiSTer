//
// ide.sv
//
// Copyright (c) 2019 György Szombathelyi
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

// altera message_off 10030
module podule_ide (
	input         clk, // system clock.
	input         reset,

	input         cpu_sel,
	input         cpu_we,
	input  [13:2] cpu_adr,
	input  [15:0] cpu_dat_i,
	output [15:0] cpu_dat_o,

	output        hdd_led,

	// place any signals that need to be passed up to the top after here.
	output  [5:0] ide_req,
	input   [4:0] ide_address,
	input         ide_write,
	input  [15:0] ide_writedata,
	input         ide_read,
	output [15:0] ide_readdata
);

// RISC Developments IDE Interface in Podule 0
reg [7:0] rd_rom[16384];
initial $readmemh("rtl/riscdevide_rom.hex", rd_rom);

wire reg_sel  = cpu_sel && cpu_adr[13:10] == 4'hA;
wire page_sel = cpu_sel && cpu_adr[13:02] == 12'h800 && cpu_we ;

reg [2:0] rd_page;
always @(posedge clk) begin 
	if (reset)         rd_page <= 0;
	else if (page_sel) rd_page <= cpu_dat_i[2:0];
end

reg [7:0] rd_rom_q;
always @(posedge clk) rd_rom_q <= rd_rom[{rd_page, cpu_adr[12:2]}];

wire [2:0]  ide_reg = cpu_adr[4:2];
wire [15:0] data_out;

assign cpu_dat_o = ~reg_sel ? {8'd0, rd_rom_q} : ((!ide_reg) ? data_out : { data_out[7:0], data_out[7:0] });
assign ide_req[5:3] = 0;

ide ide
(
	.clk(clk),
	.rst_n(~reset),

	.drq(hdd_led),
	.use_fast(0),
	.io_32(0),

	.io_address(ide_reg),
	.io_read(~cpu_we & reg_sel),
	.io_readdata(data_out),
	.io_write(cpu_we & reg_sel),
	.io_writedata(cpu_dat_i),

	.request(ide_req[2:0]),
	.mgmt_address(ide_address[3:0]),
	.mgmt_write(~ide_address[4] & ide_write),
	.mgmt_writedata(ide_writedata),
	.mgmt_read(~ide_address[4] & ide_read),
	.mgmt_readdata(ide_readdata)
);

endmodule
