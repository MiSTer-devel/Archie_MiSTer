//============================================================================
//  Acorn Archimedes
// 
//  Port to MiSTer.
//  Copyright (C) 2017-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..5 - USR1..USR4
	// Set USER_OUT to 1 to read from USER_IN.
	input   [5:0] USER_IN,
	output  [5:0] USER_OUT,

	input         OSD_STATUS
);

assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0; 
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = 0;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"ARCHIE;;",
	"J,Fire;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

/*
	24, 16,   12,   8
	25, 16.6, 12.6, 8.3
	36, 24,   18,   12
	24, 16,   12,   8
*/

vpll vpll
(
	.refclk(CLK_50M),
	.rst(reset),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.outclk_0(CLK_VIDEO)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_writedata;

altera_pll_reconfig_top #(
	.device_family       ("Cyclone V"),
	.ENABLE_MIF          (1),
	.MIF_FILE_NAME       ("vpll_conf.mif"),
	.ENABLE_BYTEENABLE   (0),
	.BYTEENABLE_WIDTH    (4),
	.RECONFIG_ADDR_WIDTH (6),
	.RECONFIG_DATA_WIDTH (32),
	.reconf_width        (64),
	.WAIT_FOR_LOCK       (1)
) vpll_cfg (
	.mgmt_reset        (reset),
	.mgmt_clk          (CLK_50M),
	.mgmt_write        (cfg_write),
	.mgmt_address      (cfg_address),
	.mgmt_writedata    (cfg_writedata),
	.mgmt_waitrequest  (cfg_waitrequest),
	.reconfig_to_pll   (reconfig_to_pll),
	.reconfig_from_pll (reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg [2:0] cfg_state = 0;
	reg       cfg_start = 0;
	reg [1:0] cfg_cur;

	if(reset) cfg_start <= 1;
	else begin
		cfg_cur <= pixbaseclk_select;
		if(cfg_cur != pixbaseclk_select) cfg_start = 1;
	
		if(!cfg_waitrequest) begin
			cfg_write <= 0;
			case(cfg_state)
				0: if(cfg_start) begin
						cfg_cur <= pixbaseclk_select;
						cfg_start <= 0;
						cfg_state <= cfg_state + 1'd1;
					end
				1: begin
						cfg_address <= 31;
						cfg_writedata <= {cfg_cur,6'b000000};
						cfg_write <= 1;
						cfg_state <= cfg_state + 1'd1;
					end
				2: cfg_state <= cfg_state + 1'd1;
				3: begin
						cfg_address <= 2;
						cfg_writedata <= 0;
						cfg_write <= 1;
						cfg_state <= cfg_state + 1'd1;
					end
				4: cfg_state <= cfg_state + 1'd1;
				5: cfg_state <= 0;
			endcase
		end
	end
end


wire pll_ready;
wire clk_128m;
wire clk_32m;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_128m),
	.outclk_1(SDRAM_CLK),
	.outclk_2(clk_32m),
	.locked(pll_ready)
);

wire reset = buttons[1] | ~initReset_n;

reg initReset_n = 0;
always @(posedge clk_32m) if(loader_active) initReset_n <= 1;

//////////////////   HPS I/O   ///////////////////
wire [15:0] joyA;
wire [15:0] joyB;
wire  [1:0] buttons;
wire [31:0] status;

wire  [7:0] kbd_out_data;
wire        kbd_out_strobe;
wire  [7:0] kbd_in_data;
wire        kbd_in_strobe;

wire [31:0] fdc_status_out;
wire [31:0] fdc_status_in;
wire  [7:0] fdc_data_in;
wire        fdc_data_in_strobe;

wire 			loader_active;
wire 			loader_we;
reg			loader_stb = 0;
wire  [3:0]	loader_sel;
wire [24:0]	loader_addr;
wire [31:0]	loader_data;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_32m),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.joystick_0(joyA),
	.joystick_1(joyB),

	.buttons(buttons),
	.status(status),

	.kbd_out_data(kbd_out_data),
	.kbd_out_strobe(kbd_out_strobe),
	.kbd_in_data(kbd_in_data),
	.kbd_in_strobe(kbd_in_strobe),

	.fdc_status_out(fdc_status_out),
	.fdc_status_in(fdc_status_in),
	.fdc_data_in_strobe(fdc_data_in_strobe),
	.fdc_data_in(fdc_data_in),

	.ioctl_wr(loader_we),
	.ioctl_addr(loader_addr),
	.ioctl_dout(loader_data),
	.ioctl_download(loader_active),
	.ioctl_sel(loader_sel),

	.sd_lba(0),
	.sd_rd(0),
	.sd_wr(0),
	.sd_conf(0),
	.sd_buff_din(0),
	.ioctl_wait(loader_stb)
);

assign AUDIO_S = 0;
assign AUDIO_MIX = status[3:2];

wire [3:0]	core_r, core_g, core_b;
wire			core_hs, core_vs;

assign VGA_R  = {core_r,core_r};
assign VGA_G  = {core_g,core_g};
assign VGA_B  = {core_b,core_b};
assign VGA_HS = ~core_hs;
assign VGA_VS = ~core_vs;
assign VGA_F1 = 0;
assign VGA_SL = 0;

wire			core_ack_in;
wire			core_stb_out;
wire 			core_cyc_out;
wire			core_we_o;
wire [3:0]	core_sel_o;
wire [2:0]	core_cti_o;
wire [31:0] core_data_in, core_data_out;
wire [31:0] ram_data_in;
wire [26:2] core_address_out;

wire	[1:0]	pixbaseclk_select;

wire 			i2c_din, i2c_dout, i2c_clock;

archimedes_top ARCHIMEDES
(
	.CLKCPU_I	( clk_32m			),
	.CLKPIX_I	( CLK_VIDEO			),
	.CEPIX_O	 	( CE_PIXEL			),

	.RESET_I	   (~ram_ready | loader_active | reset),

	.MEM_ACK_I	( core_ack_in		),
	.MEM_DAT_I	( core_data_in		),
	.MEM_DAT_O	( core_data_out	),
	.MEM_ADDR_O	( core_address_out),
	.MEM_STB_O	( core_stb_out		),
	.MEM_CYC_O	( core_cyc_out		),
	.MEM_SEL_O	( core_sel_o		),
	.MEM_WE_O	( core_we_o			),
	.MEM_CTI_O  ( core_cti_o      ),

	.HSYNC		( core_hs			),
	.VSYNC		( core_vs			),

	.VIDEO_R		( core_r				),
	.VIDEO_G		( core_g				),
	.VIDEO_B		( core_b				),
	.VIDEO_EN   ( VGA_DE          ),

	.AUDIO_L		( AUDIO_L			),
	.AUDIO_R		( AUDIO_R			),

	.I2C_DOUT	( i2c_din			),
	.I2C_DIN		( i2c_dout			),
	.I2C_CLOCK	( i2c_clock			),

	.DEBUG_LED	(    					),

	.FDC_DIO_STATUS_OUT ( fdc_status_out  ),
	.FDC_DIO_STATUS_IN  ( fdc_status_in  ),
	.FDC_DIN_STROBE ( fdc_data_in_strobe  ),
	.FDC_DIN        ( fdc_data_in  ),

	.KBD_OUT_DATA   ( kbd_out_data   ),
	.KBD_OUT_STROBE ( kbd_out_strobe ),
	.KBD_IN_DATA    ( kbd_in_data    ),
	.KBD_IN_STROBE  ( kbd_in_strobe  ),

	.JOYSTICK0		 (~{joyA[4], joyA[0],joyA[1],joyA[2],joyA[3]}),
	.JOYSTICK1		 (~{joyB[4], joyB[0],joyB[1],joyB[2],joyB[3]}),
	.VIDBASECLK_O	 ( pixbaseclk_select ),
	.VIDSYNCPOL_O	 ( )
);

wire			ram_ack;
wire			ram_stb;
wire			ram_cyc;
wire			ram_we;
wire  [3:0]	ram_sel;
wire [25:0] ram_address;
wire			ram_ready;

sdram_top SDRAM
(
	// wishbone interface
	.wb_clk		(clk_32m		 ),
	.wb_stb		(ram_stb		 ),
	.wb_cyc		(ram_cyc		 ),
	.wb_we		(ram_we		 ),
	.wb_ack		(ram_ack		 ),

	.wb_sel		(ram_sel		 ),
	.wb_adr		(ram_address ),
	.wb_dat_i	(ram_data_in ),
	.wb_dat_o	(core_data_in),
	.wb_cti		(core_cti_o	 ),

	// SDRAM Interface
	.sd_clk		(clk_128m	 ),
	.sd_rst		(~pll_ready	 ),

	.sd_cke		(SDRAM_CKE	 ),
	.sd_dq   	(SDRAM_DQ  	 ),
	.sd_addr 	(SDRAM_A     ),
	.sd_dqm     ({SDRAM_DQMH,SDRAM_DQML}),
	.sd_cs_n    (SDRAM_nCS   ),
	.sd_ba      (SDRAM_BA  	 ),
	.sd_we_n    (SDRAM_nWE   ),
	.sd_ras_n   (SDRAM_nRAS  ),
	.sd_cas_n   (SDRAM_nCAS  ),
	.sd_ready	(ram_ready   )
);

i2cSlaveTop CMOS
(
	.clk		(clk_32m	 ),
	.rst		(~pll_ready ),
	.sdaIn	(i2c_din	 ),
	.sdaOut	(i2c_dout	 ),
	.scl		(i2c_clock	 )
);

always @(posedge clk_32m) begin 
	if (loader_we) loader_stb <= 1'b1;
		else if (ram_ack) loader_stb <= 1'b0;
end

assign ram_we		 = loader_active ? loader_active : core_we_o;
assign ram_sel		 = loader_active ? loader_sel : core_sel_o;
assign ram_address = loader_active ? {loader_addr[23:2],2'b00} : {core_address_out[23:2],2'b00};
assign ram_stb		 = loader_active ? loader_stb : core_stb_out;
assign ram_cyc		 = loader_active ? loader_stb : core_stb_out;
assign ram_data_in = loader_active ? loader_data : core_data_out;
assign core_ack_in = loader_active ? 1'b0 : ram_ack;

endmodule
