`timescale 1ns / 1ps
// archimedes_top.v
//
// Archimedes top
//
// Copyright (c) 2014 Stephen J. Leary <sleary@vavi.co.uk>
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

module archimedes_top #(parameter CLKCPU)
(
	// base CPU Clock
	input          CLKCPU_I,

	input          CLKPIX_I,
	input          CEPIX_I,
	output   [1:0] SELPIX_O,

	input          CEAUD_I,

	input          RESET_I,

	// cpu wishbone interface.
	output         MEM_CYC_O,
	output         MEM_STB_O,
	output         MEM_WE_O,

	input          MEM_ACK_I,
	input          MEM_ERR_I,
	input          MEM_RTY_I,

	output   [3:0] MEM_SEL_O,
	output   [2:0] MEM_CTI_O,
	output  [23:2] MEM_ADDR_O,

	input   [31:0] MEM_DAT_I,
	output  [31:0] MEM_DAT_O,

	// video signals (VGA)
	output         HSYNC,
	output         VSYNC,

	output   [3:0] VIDEO_R,
	output   [3:0] VIDEO_G,
	output   [3:0] VIDEO_B,
	output         VIDEO_EN,

	// VIDC Enhancer selection.
	// These are from external latch C
	output   [1:0] VIDBASECLK_O,
	output   [1:0] VIDSYNCPOL_O,

	// I2C bus to the CMOS.
	output         I2C_DOUT,
	input          I2C_DIN,
	output         I2C_CLOCK,

	output         fdd_led,
	output         hdd_led,

	// floppy connections to external controller
	input    [1:0] img_mounted, // signaling that new image has been mounted
	input          img_wp,      // write protect. latched at img_mounted
	input   [31:0] img_size,    // size of image in bytes
	output  [31:0] sd_lba,
	output   [1:0] sd_rd,
	output   [1:0] sd_wr,
	input          sd_ack,
	input    [7:0] sd_buff_addr,
	input   [15:0] sd_buff_dout,
	output  [15:0] sd_buff_din,
	input          sd_buff_wr,

	// connection to the IDE controller
	output   [5:0] ide_req,
	input    [4:0] ide_address,
	input          ide_write,
	input   [15:0] ide_writedata,
	input          ide_read,
	output  [15:0] ide_readdata,

	// connection to keyboard controller
	output   [7:0] KBD_OUT_DATA,
	output         KBD_OUT_STROBE,
	input    [7:0] KBD_IN_DATA,
	input          KBD_IN_STROBE,

	input    [4:0] JOYSTICK0,
	input    [4:0] JOYSTICK1,

	// audio signal.
	output  [15:0] AUDIO_L,
	output  [15:0] AUDIO_R

);

// cpu bus
wire [31:0] cpu_address;
wire [3:0]  cpu_sel;


wire        cpu_spvmd;
wire [31:0] cpu_dat_o;
wire [31:0] cpu_dat_i;

wire        cpu_cyc;
wire        cpu_stb;
wire        cpu_we;

wire        cpu_ack;
wire        cpu_err;
wire        cpu_irq;
wire        cpu_firq;

// video DMA signals.
wire [31:0] vid_address; // VIDC D31-D0
wire        vid_flybk; // VIDC FLYBK
wire        vid_req; // VIDC REQ
wire        vid_ack; // VIDC ACK

wire        ioc_cs;
wire        ioc_ack;
wire [7:0]  ioc_dat_o;

wire        rom_low_cs;
wire [5:0]  ioc_cin, ioc_cout;

a23_core ARM(

	.i_clk      ( CLKCPU_I     ),
	.i_reset    ( RESET_I      ),

	.o_wb_cyc   ( cpu_cyc      ),
	.o_wb_stb   ( cpu_stb      ),
	.o_wb_we    ( cpu_we       ),

	.o_wb_adr   ( cpu_address  ),
	.o_wb_sel   ( cpu_sel      ),

	.i_wb_dat   ( cpu_dat_i    ),
	.o_wb_dat   ( cpu_dat_o    ),


	.i_wb_ack   ( cpu_ack      ),
	.i_wb_err   ( cpu_err      ),

	.o_wb_tga   ( cpu_spvmd    ),
	.i_irq      ( cpu_irq      ),
	.i_firq     ( cpu_firq     ),

	.i_system_rdy(~RESET_I  )
);

wire sirq_n;
wire ram_cs;
wire vid_we;
wire snd_ack, snd_req;
wire [31:0] cpu_dout;

memc MEMC(

	.clkcpu        ( CLKCPU_I     ),
	.rst_i         ( RESET_I      ),

	.spvmd         ( cpu_spvmd    ),

	// cpu interface
	.cpu_address   ( cpu_address[25:0]  ),
	.cpu_cyc       ( cpu_cyc      ),
	.cpu_stb       ( cpu_stb      ),
	.cpu_we        ( cpu_we       ),
	.cpu_sel       ( cpu_sel      ),
	.cpu_ack       ( cpu_ack      ),
	.cpu_err       ( cpu_err      ),
	.cpu_dout      ( cpu_dout     ),

	// memory interface
	.mem_addr_o    ( MEM_ADDR_O   ),
	.mem_stb_o     ( MEM_STB_O    ),
	.mem_cyc_o     ( MEM_CYC_O    ),
	.mem_ack_i     ( MEM_ACK_I    ),
	.mem_sel_o     ( MEM_SEL_O    ),
	.mem_we_o      ( MEM_WE_O     ),
	.mem_cti_o     ( MEM_CTI_O    ),
	.mem_dat_i     ( MEM_DAT_I    ),

	// vidc interface
	.hsync         ( HSYNC        ),
	.flybk         ( vid_flybk    ),
	.vidrq         ( vid_req      ),
	.vidak         ( vid_ack      ),
	.sndak         ( snd_ack      ),
	.sndrq         ( snd_req      ),
	.vidw          ( vid_we       ),

	// ioc interface
	.ioc_cs        ( ioc_cs       ),
	.rom_low_cs    ( rom_low_cs   ),
	.ram_cs        ( ram_cs       ),

	// irqs

	.sirq_n        ( sirq_n       )
);

vidc #(CLKCPU) VIDC
(
	.clkpix    ( CLKPIX_I  ),
	.cepix     ( CEPIX_I   ),
	.selpix    ( SELPIX_O  ),

	.ceaud     ( CEAUD_I   ),

	.clkcpu    ( CLKCPU_I  ),
	.rst_i     ( RESET_I   ),

	.cpu_dat   ( cpu_dat_o ),

	// memc
	.flybk     ( vid_flybk ),
	.vidak     ( vid_ack   ),
	.vidrq     ( vid_req   ),
	.sndak     ( snd_ack   ),
	.sndrq     ( snd_req   ),

	.viddat    ( MEM_DAT_I ),
	.vidw      ( vid_we    ),

	// video signals
	.hsync     ( HSYNC     ),
	.vsync     ( VSYNC     ),
	.video_r   ( VIDEO_R   ),
	.video_g   ( VIDEO_G   ),
	.video_b   ( VIDEO_B   ),
	.video_en  ( VIDEO_EN  ),

	// audio signals
	.audio_l   ( AUDIO_L   ),
	.audio_r   ( AUDIO_R   )
);

wire [1:0]  ioc_speed = cpu_address[20:19];
wire [7:1]  ioc_select;
wire        ioc_sext;
// podule data bus.
wire [15:0] pod_dat_o;
wire [15:0] pod_dat_i;

wire floppy_firq;
wire floppy_drq;

wire ioc_clk7m_en;

ioc IOC(

	.clkcpu        ( CLKCPU_I           ),
	.clk7m_en      ( ioc_clk7m_en       ),

	.por           ( RESET_I            ),
	.ir            ( vid_flybk          ),

	.fh            ( {floppy_firq, floppy_drq}),

	.il            ( {6'b1111, sirq_n, 1'b1 }),

	.c_in          ( ioc_cin            ),
	.c_out         ( ioc_cout           ),

	.select        ( ioc_select         ),
	.sext          ( ioc_sext           ),

	// wishbone bus
	.wb_adr        ( cpu_address[6:2]   ),
	.wb_stb        ( cpu_stb & cpu_address[21] & ioc_cs ),
	.wb_cyc        ( cpu_cyc & cpu_address[21] & ioc_cs ),
	.wb_we         ( cpu_we             ),

	.wb_dat_i      ( cpu_dat_o[23:16]   ),
	.wb_dat_o      ( ioc_dat_o          ),
	.wb_bank       ( cpu_address[18:16] ),

	.irq           ( cpu_irq            ),
	.firq          ( cpu_firq           ),

	.kbd_out_data  ( KBD_OUT_DATA       ),
	.kbd_out_strobe( KBD_OUT_STROBE     ),
	.kbd_in_data   ( KBD_IN_DATA        ),
	.kbd_in_strobe ( KBD_IN_STROBE      )
);

localparam PODULE0 = 2'b00;
localparam PODULE1 = 2'b01;
localparam PODULE2 = 2'b10;
localparam PODULE3 = 2'b11;

wire        podules_en   = ioc_cs & ioc_select[4];
wire  [1:0] podule_num   = cpu_address[15:14];
wire [15:0] podule_wdata = cpu_dat_o[31:16];
wire [13:2] podule_adr   = cpu_address[13:2];

wire [15:0] podule0_rdata;
wire [15:0] podule1_rdata;
wire [15:0] podule2_rdata;
wire [15:0] podule3_rdata;

reg  [15:0] podule_rdata;
always @(*) begin
	podule_rdata = 16'hFFFF;

	if(podule_num == PODULE0) podule_rdata = podule0_rdata;
	//if(podule_num == PODULE1) podule_rdata = podule1_rdata;
	//if(podule_num == PODULE2) podule_rdata = podule2_rdata;
	//if(podule_num == PODULE3) podule_rdata = podule3_rdata;
end

wire podule0_sel = podules_en && cpu_stb && cpu_cyc && podule_num == PODULE0;
//wire podule1_sel = podules_en && cpu_stb && cpu_cyc && podule_num == PODULE1;
//wire podule2_sel = podules_en && cpu_stb && cpu_cyc && podule_num == PODULE2;
//wire podule3_sel = podules_en && cpu_stb && cpu_cyc && podule_num == PODULE3;


wire  [7:0] floppy_dat_o;
wire        floppy_en = ioc_cs & ioc_select[1];

// floppy drive signals.
wire  [3:0] floppy_drive;
wire        floppy_side;
wire        floppy_motor;
wire        floppy_inuse;
wire        floppy_density;
wire        floppy_reset;

wire        fdc_sel = cpu_stb & cpu_cyc & floppy_en;
fdc1772 #(.EXT_MOTOR(1'b1), .CLK_EN(16'd7000)) FDC1772
(
	.clkcpu         ( CLKCPU_I         ),
	.clk8m_en       ( ioc_clk7m_en     ),

	.cpu_sel        ( fdc_sel          ),
	.cpu_rw         ( !cpu_we          ),
	.cpu_addr       ( cpu_address[3:2] ),
	.cpu_dout       ( floppy_dat_o     ),
	.cpu_din        ( cpu_dat_o[23:16] ),

	.irq            ( floppy_firq      ),
	.drq            ( floppy_drq       ),

	.img_mounted    ( img_mounted      ),
	.img_size       ( img_size         ),
	.img_wp         ( img_wp           ),
	.sd_lba         ( sd_lba           ),
	.sd_rd          ( sd_rd            ),
	.sd_wr          ( sd_wr            ),
	.sd_ack         ( sd_ack           ),
	.sd_buff_addr   ( sd_buff_addr     ),
	.sd_dout        ( sd_buff_dout     ),
	.sd_din         ( sd_buff_din      ),
	.sd_dout_strobe ( sd_buff_wr       ),

	.floppy_drive   ( floppy_drive     ),
	.floppy_motor   ( !floppy_motor    ),
// .floppy_inuse   ( floppy_inuse     ),
	.floppy_side    ( floppy_side      ),
// .floppy_density ( floppy_density   ),
	.floppy_reset   ( floppy_reset     )
);


podule_ide IDE (
	.clk            ( CLKCPU_I         ),
	.reset          ( RESET_I          ),

	.cpu_sel        ( podule0_sel      ),
	.cpu_we         ( cpu_we           ),
	.cpu_adr        ( podule_adr       ),
	.cpu_dat_o      ( podule0_rdata    ),
	.cpu_dat_i      ( podule_wdata     ),

	.hdd_led        ( hdd_led          ),

	.ide_req        ( ide_req          ),
	.ide_address    ( ide_address      ),
	.ide_write      ( ide_write        ),
	.ide_writedata  ( ide_writedata    ),
	.ide_read       ( ide_read         ),
	.ide_readdata   ( ide_readdata     )
);

wire [7:0] latches_dat_o;
wire       latches_en = ioc_cs & ioc_select[5] & (ioc_speed == 2'd2);

latches LATCHES(

	.clkcpu        ( CLKCPU_I             ),

	.wb_cyc        ( cpu_cyc & latches_en ),
	.wb_stb        ( cpu_stb & latches_en ),
	.wb_we         ( cpu_we  & latches_en ),

	.wb_dat_i      ( cpu_dat_o[23:16]     ),
	.wb_dat_o      ( latches_dat_o        ),
	.wb_adr        ( cpu_address[15:2]    ),

	.floppy_drive  ( floppy_drive         ),
	.floppy_motor  ( floppy_motor         ),
	.floppy_inuse  ( floppy_inuse         ),
	.floppy_side   ( floppy_side          ),
	.floppy_density( floppy_density       ),
	.floppy_reset  ( floppy_reset         ),

	.joy0          ( JOYSTICK0            ),
	.joy1          ( JOYSTICK1            ),

	.baseclk       ( VIDBASECLK_O         ),
	.syncpol       ( VIDSYNCPOL_O         )
);


assign MEM_DAT_O = cpu_dat_o;
assign cpu_dat_i = floppy_en          ? {24'd0, floppy_dat_o} :
						 latches_en         ? {24'd0, latches_dat_o} :
						 podules_en         ? {16'd0, podule_rdata} :
						 ioc_cs & ~ioc_sext ? {24'd0, ioc_dat_o} :
						 ram_cs             ? cpu_dout :
						 32'hFFFF_FFFF;

assign I2C_CLOCK = ioc_cout[1];
assign I2C_DOUT  = ioc_cout[0];

assign ioc_cin[5:0] = {ioc_cout[5:2], I2C_CLOCK, I2C_DIN};
assign fdd_led      = ~floppy_inuse;

endmodule
