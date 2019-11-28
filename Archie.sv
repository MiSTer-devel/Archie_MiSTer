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
	inout  [45:0] HPS_BUS,

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

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
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
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0; 
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = 0;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"ARCHIE;;",
	"J,Fire;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire pll_ready;
wire clk_mem;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_mem),
	.outclk_1(clk_sys),
	.locked(pll_ready)
);

//////////////////   HPS I/O   ///////////////////
wire [15:0] joyA;
wire [15:0] joyB;
wire  [1:0] buttons;
wire [31:0] status;

wire  [7:0] kbd_out_data;
wire        kbd_out_strobe;
wire  [7:0] kbd_in_data;
wire        kbd_in_strobe;

wire [64:0] RTC;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [31:0] img_size;
wire        img_readonly;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.joystick_0(joyA),
	.joystick_1(joyB),

	.buttons(buttons),
	.status(status),
	.new_vmode(new_vmode),
	.gamma_bus(gamma_bus),

	.RTC(RTC),

	.kbd_out_data(kbd_out_data),
	.kbd_out_strobe(kbd_out_strobe),
	.kbd_in_data(kbd_in_data),
	.kbd_in_strobe(kbd_in_strobe),

	.ioctl_index(ioctl_index),
	.ioctl_download(ioctl_download),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_wait(loader_stb),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly)
);

assign AUDIO_S = 1;
assign AUDIO_MIX = status[3:2];

wire [3:0]	core_r, core_g, core_b;
wire			core_hs, core_vs, core_de;

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

wire reset = status[0] | buttons[1] | ~initReset_n | ioctl_download;

reg initReset_n = 0;
always @(posedge clk_sys) if(ioctl_download) initReset_n <= 1;

wire [1:0] selpix;

archimedes_top #(CLKSYS) ARCHIMEDES
(
	.CLKCPU_I	( clk_sys			),
	.CLKPIX_I	( CLK_VIDEO			),
	.CEPIX_I	 	( CE_PIXEL			),
	.SELPIX_O	( selpix				), 

	.CEAUD_I	 	( ceaud  			),

	.RESET_I	   (~ram_ready | reset),

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
	.VIDEO_EN   ( core_de         ),

	.AUDIO_L		( AUDIO_L			),
	.AUDIO_R		( AUDIO_R			),

	.I2C_DOUT	( i2c_din			),
	.I2C_DIN		( i2c_dout			),
	.I2C_CLOCK	( i2c_clock			),

	.DEBUG_LED	(    					),

	.sd_lba       ( sd_lba       ),
	.sd_rd        ( sd_rd        ),
	.sd_wr        ( sd_wr        ),
	.sd_ack       ( sd_ack       ),
	.sd_buff_addr ( sd_buff_addr ),
	.sd_buff_dout ( sd_buff_dout ),
	.sd_buff_din  ( sd_buff_din  ),
	.sd_buff_wr   ( sd_buff_wr   ),
	.img_mounted  ( img_mounted  ),
	.img_size     ( img_size     ),
	.img_wp       ( img_readonly ),

	.KBD_OUT_DATA   ( kbd_out_data   ),
	.KBD_OUT_STROBE ( kbd_out_strobe ),
	.KBD_IN_DATA    ( kbd_in_data    ),
	.KBD_IN_STROBE  ( kbd_in_strobe  ),

	.JOYSTICK0		 (~{joyA[4],joyA[0],joyA[1],joyA[2],joyA[3]}),
	.JOYSTICK1		 (~{joyB[4],joyB[0],joyB[1],joyB[2],joyB[3]}),
	.VIDBASECLK_O	 ( pixbaseclk_select ),
	.VIDSYNCPOL_O	 ( )
);

wire [31:0] vratio[16] = 
'{
	8000000, 12000000, 16000000, 24000000,
	8391666, 12587500, 16783333, 25175000,
	1200000, 18000000, 24000000, 36000000,
	8000000, 12000000, 16000000, 24000000
};

wire [3:0] vmode = {pixbaseclk_select,selpix};

localparam  CLKSYS = 42000000;

reg         cepix;
reg  [31:0] vclk, vsum;
wire [31:0] vsum_next = vsum + vclk;
always @(posedge CLK_VIDEO) begin
	cepix <= 0;
	vsum <= vsum_next;
	if(vsum_next >= CLKSYS) begin
		vsum <= vsum_next - CLKSYS;
		cepix <= 1;
	end
end

always @(posedge CLK_VIDEO) begin
	reg [31:0] pixcnt = 0, pix60;
	reg old_sync = 0;
	reg [31:0] vclk1;

	reg allow60 = 0;

	if(vmode == 7) allow60 <= 1;
	if(reset) allow60 <= 0;

	if(reset || status[4] || !allow60) vclk1 <= vratio[vmode];
	else if(CE_PIXEL) begin
		old_sync <= VGA_VS;
		pixcnt <= pixcnt + 1;
		if(~old_sync & VGA_VS) begin
			pix60 <= {pixcnt[26:0],5'd0}+{pixcnt[27:0],4'd0}+{pixcnt[28:0],3'd0}+{pixcnt[29:0],2'd0};
			pixcnt <= 0;
		end
		
		if(pix60<5000000) vclk1 <= 5000000;
		else if(pix60>CLKSYS) vclk1 <= CLKSYS;
		else vclk1 <= pix60;
	end

	vclk <= vclk1;
end

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL  = cepix;
assign VGA_F1 = 0;
assign VGA_SL = 0;

gamma_fast gamma
(
	.clk_vid(CLK_VIDEO),
	.ce_pix(CE_PIXEL),

	.gamma_bus(gamma_bus),

	.HSync(~core_hs),
	.VSync(~core_vs),
	.DE(core_de),
	.RGB_in({core_r,core_r,core_g,core_g,core_b,core_b}),

	.HSync_out(VGA_HS),
	.VSync_out(VGA_VS),
	.DE_out(VGA_DE),
	.RGB_out({VGA_R,VGA_G,VGA_B})
);

reg new_vmode;
always @(posedge CLK_VIDEO) begin
	reg [4:0] old_mode;
	
	old_mode <= {status[4], vmode};
	if(old_mode != {status[4], vmode}) new_vmode <= ~new_vmode;
end


wire [31:0] aratio[4] = 
'{
	1000000, 1048958, 1500000, 1000000
};

reg         ceaud;
reg  [31:0] asum, aclk;
wire [31:0] asum_next = asum + aclk;
always @(posedge CLK_VIDEO) begin
	reg [31:0] aclk1;

	aclk1 <= (status[5] && pixbaseclk_select == 1) ? 1000000 : aratio[pixbaseclk_select];
	aclk <= aclk1;

	ceaud <= 0;
	asum <= asum_next;
	if(asum_next >= CLKSYS) begin
		asum <= asum_next - CLKSYS;
		ceaud <= 1;
	end
end

wire			ram_ack;
wire			ram_stb;
wire			ram_cyc;
wire			ram_we;
wire  [3:0]	ram_sel;
wire [25:0] ram_address;
wire			ram_ready;

sdram SDRAM
(
	// wishbone interface
	.wb_clk		(clk_sys		 ),
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
	.sd_clk		(clk_mem	 ),
	.sd_rst		(~pll_ready	 ),

	.sd_clk_out (SDRAM_CLK   ),
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

i2cSlave CMOS
(
	.clk		(clk_sys	 ),
	.rst		(~pll_ready ),
	.sdaIn	(i2c_din	 ),
	.sdaOut	(i2c_dout	 ),
	.scl		(i2c_clock	 ),

	.RTC     (RTC),
	
	.dl_addr(cmos_dl_addr),
	.dl_data(cmos_dl_addr[0] ? ioctl_dout[15:8] : ioctl_dout[7:0]),
	.dl_wr(|cmos_dl_wr),
	.dl_en(cmos_dl)
);

wire riscos_dl = (ioctl_index == 1) && ioctl_download;
wire cmos_dl   = (ioctl_index == 3) && ioctl_download;

wire [7:0] cmos_dl_addr;
wire [1:0] cmos_dl_wr;

reg loader_stb = 0;
always @(posedge clk_sys) begin 
	if (ram_ack) loader_stb <= 0;
	if(riscos_dl & ioctl_wr) loader_stb <= 1;

	cmos_dl_addr <= cmos_dl_addr + 1'd1;
	cmos_dl_wr <= {cmos_dl_wr[0],1'b0};

	if(cmos_dl) begin
		if(ioctl_wr) begin
			cmos_dl_addr <= ioctl_addr[7:0];
			cmos_dl_wr <= 1;
		end
	end
end

assign ram_we		 = riscos_dl ? 1'b1 : core_we_o;
assign ram_sel		 = riscos_dl ? (ioctl_addr[1] ? 4'b1100 : 4'b0011) : core_sel_o;
assign ram_address = riscos_dl ? 25'h400000 + {ioctl_addr[23:2],2'b00} : {core_address_out[23:2],2'b00};
assign ram_stb		 = riscos_dl ? loader_stb : core_stb_out;
assign ram_cyc		 = riscos_dl ? loader_stb : core_stb_out;
assign ram_data_in = riscos_dl ? {ioctl_dout,ioctl_dout} : core_data_out;
assign core_ack_in = riscos_dl ? 1'b0 : ram_ack;

endmodule
