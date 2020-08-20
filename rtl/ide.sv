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
module ide (
	input         clk, // system clock.
	input         reset,

	input         cpu_sel,
	input         cpu_we,
	input  [13:2] cpu_adr,
	input  [15:0] cpu_dat_i,
	output [15:0] cpu_dat_o,

	// place any signals that need to be passed up to the top after here.
	output        ide_req,
	input         ide_err,
	input         ide_ack,
	input   [8:0] ide_adr,
	output [15:0] ide_dat_o,
	input  [15:0] ide_dat_i,
	input         ide_we,
	input         ide_rd
);

assign ide_req = ide_cmd_req | ide_sector_req;

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

wire [2:0] ide_reg = cpu_adr[4:2];

reg [7:0] taskfile[8];
reg [7:0] status;

wire ide_reg_sel = ide_adr[8];

// read from Task File Registers
//cpu read
wire [7:0] ide_dat_b = (ide_reg == 3'd7) ? { status[7:1], ide_err } : taskfile[ide_reg];
assign     cpu_dat_o = ~reg_sel ? {8'd0, rd_rom_q} : ((ide_reg == 3'd0) ? data_out : { ide_dat_b, ide_dat_b });

// IO controller read
assign     ide_dat_o = ide_reg_sel ? taskfile[ide_adr[2:0]] : ide_sec_o;

reg ide_cmd_req;
// write to Task File Registers
always @(posedge clk) begin
	ide_cmd_req <= 0;
	// cpu write
	if (reg_sel && cpu_we) begin
		taskfile[ide_reg] <= cpu_dat_i[7:0];
		// writing to the command register triggers the IO controller
		if (ide_reg == 3'd7) ide_cmd_req <= 1;
	end

	// IO controller write
	if (ide_we & ide_reg_sel) taskfile[ide_adr[2:0]] <= ide_dat_i[7:0];
end

reg ide_sector_req;

// status register handling
always @(posedge clk) begin
	reg [7:0] sector_count;

	if (reset) begin
		status <= 8'h48;
		ide_sector_req <= 0;
		sector_count <= 8'd1;
	end else begin
		// write to command register starts the execution
		if (reg_sel && cpu_we && ide_reg == 3'd7) begin
			sector_count <= taskfile[2];
			case (taskfile[7])
				8'h30, 8'hc5: status <= 8'h08; // request data
				default: status <= 8'h80; // busy
			endcase
		end

		if (ide_ack) begin
			case (taskfile[7])
				8'hec : status <= 8'h08; // ready to transfer
				8'h20, 8'h30, 8'hc4, 8'hc5: ;
				default: status <= 8'h40; // ready
			endcase
		end

		// sector buffer - IO controller side
		if ((ide_rd | ide_we) && ide_adr == 9'hff) status <= 8'h08; // sector buffer consumed/filled, ready to transfer
		if ((ide_rd | ide_we) && ~ide_reg_sel) ide_sector_req <= 0;

		// sector buffer - CPU side
		if (reg_sel_d && ~reg_sel && ide_reg == 3'd0 && data_addr == 8'hff) begin
			status <= 8'h40; // ready
			case (taskfile[7])
				8'h20, 8'hc4: // reads
				begin
					sector_count <= sector_count - 1'd1;
					if (sector_count != 1) ide_sector_req <= 1; // request the next sector
				end
				8'h30, 8'hc5:
				begin
					ide_sector_req <= 1; // write, signals the write buffer is ready
					status <= 8'h80; // busy
				end
				default: ;
			endcase

		end
	end
end

reg   [7:0] data_addr;
wire [15:0] data_out;
reg         reg_sel_d;

// read/write data register
always @(posedge clk) begin
	reg_sel_d <= reg_sel;
	if (reg_sel && cpu_we && ide_reg == 3'd7) data_addr <= 0;
	if (reg_sel_d && ~reg_sel && ide_reg == 3'd0) data_addr <= data_addr + 1'd1;
end

wire [15:0] ide_sec_o;
dpram #(8,16) ide_databuf (
	.clock     ( clk            ),

	.address_a ( data_addr      ),
	.data_a    ( cpu_dat_i      ),
	.wren_a    ( reg_sel && cpu_we && ide_reg == 3'd0 ),
	.q_a       ( data_out       ),

	.address_b ( ide_adr[7:0]   ),
	.data_b    ( ide_dat_i      ),
	.wren_b    ( ide_we & ~ide_reg_sel ),
	.q_b       ( ide_sec_o      )
);

endmodule
