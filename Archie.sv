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
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0; 
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = fdd_led;
assign LED_DISK  = hdd_led;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign VGA_DISABLE = 0;

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!status[7:6]) ? 8'd4 : (status[7:6] - 1'd1)),
	.ARY((!status[7:6]) ? 8'd3 : 8'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[9:8])
);

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
wire video_pll_locked;
wire [63:0] video_reconfig_to_pll;
wire [63:0] video_reconfig_from_pll;
wire video_cfg_waitrequest;
wire video_cfg_write;
wire [5:0] video_cfg_address;
wire [31:0] video_cfg_writedata;
wire [31:0] video_cfg_readdata;
wire video_cfg_busy;
wire [1:0] pixbaseclk_select;
wire hires_mono;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg hires_mono_sys_sync1 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg hires_mono_sys_sync2 = 0;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_mem),
	.outclk_1(clk_sys),
	.locked(pll_ready)
);

reg initReset_n = 0;
always @(posedge clk_sys) if(riscos_dl) initReset_n <= 1;

wire reset = status[0] | buttons[1] | RESET | ~initReset_n | riscos_dl;

wire core_reset = ~ram_ready | reset;
wire video_reset_request = core_reset | ~video_pll_locked | video_cfg_busy;
reg [1:0] video_reset_sync = 2'b11;
wire video_reset = video_reset_sync[1];
reg [1:0] video_command_reset_sync = 2'b11;
wire video_command_reset = video_command_reset_sync[1];
always @(posedge CLK_VIDEO) begin
	video_reset_sync <= {video_reset_sync[0], video_reset_request};
	video_command_reset_sync <= {video_command_reset_sync[0], core_reset};
end

video_pll VIDEO_PLL
(
	.refclk ( CLK_50M          ),
	.rst    ( reset            ),
	.outclk ( CLK_VIDEO        ),
	.locked ( video_pll_locked ),
	.reconfig_to_pll   ( video_reconfig_to_pll   ),
	.reconfig_from_pll ( video_reconfig_from_pll )
);

pll_cfg VIDEO_PLL_CFG
(
	.mgmt_clk          ( clk_sys                 ),
	.mgmt_reset        ( reset                   ),
	.mgmt_waitrequest  ( video_cfg_waitrequest   ),
	.mgmt_write        ( video_cfg_write         ),
	.mgmt_read         ( 1'b0                    ),
	.mgmt_address      ( video_cfg_address       ),
	.mgmt_writedata    ( video_cfg_writedata     ),
	.mgmt_readdata     ( video_cfg_readdata      ),
	.reconfig_to_pll   ( video_reconfig_to_pll   ),
	.reconfig_from_pll ( video_reconfig_from_pll )
);

// VIDC base-clock families 0 and 3 use a 48 MHz parent, family 1 uses
// 50.35 MHz, and family 2 uses 72 MHz. Mode 23 uses 96 MHz to serialize
// four monochrome dots from each 24 MHz VIDC pixel period.
always @(posedge clk_sys) begin
	hires_mono_sys_sync1 <= hires_mono;
	hires_mono_sys_sync2 <= hires_mono_sys_sync1;
end
wire [1:0] desired_video_profile = hires_mono_sys_sync2 ? 2'd3 :
	                                 (pixbaseclk_select == 2'd1) ? 2'd1 :
	                                 (pixbaseclk_select == 2'd2) ? 2'd2 : 2'd0;
video_pll_profile VIDEO_PLL_PROFILE
(
	.clk             ( clk_sys               ),
	.reset           ( reset                 ),
	.desired_profile ( desired_video_profile ),
	.busy            ( video_cfg_busy        ),
	.write           ( video_cfg_write       ),
	.address         ( video_cfg_address     ),
	.writedata       ( video_cfg_writedata   ),
	.waitrequest     ( video_cfg_waitrequest )
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

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire [15:0] ioctl_din;
reg         ioctl_wait = 0;

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire  [1:0] sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [31:0] img_size;
wire        img_readonly;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.joystick_0(joyA),
	.joystick_1(joyB),

	.buttons(buttons),
	.status(status),
	.new_vmode(new_vmode),
	.gamma_bus(gamma_bus),

	.ioctl_index(ioctl_index),
	.ioctl_download(ioctl_download),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_wait(ioctl_wait|loader_stb),
	.ioctl_din(ioctl_din),

	.sd_lba('{sd_lba,sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din,sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly),

	.EXT_BUS(EXT_BUS)
);

wire [35:0] EXT_BUS;
hps_ext hps_ext
(
	.clk_sys        ( clk_sys        ),
	.EXT_BUS        ( EXT_BUS        ),

	.kbd_out_data   ( kbd_out_data   ),
	.kbd_out_strobe ( kbd_out_strobe ),
	.kbd_in_data    ( kbd_in_data    ),
	.kbd_in_strobe  ( kbd_in_strobe  ),

	.cmos_cnt       ( cmos_cnt       ),

	.ide_req        ( ide_req        ),
	.ide_addr       ( ide_address    ),
	.ide_wr         ( ide_write      ),
	.ide_dout       ( ide_writedata  ),
	.ide_rd         ( ide_read       ),
	.ide_din        ( ide_readdata   )
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
wire [23:2] core_address_out;
wire CE_VIDC;

wire  [1:0] selpix;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [1:0] pixbaseclk_video_sync1 = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [1:0] pixbaseclk_video_sync2 = 0;
wire [1:0] pixbaseclk_video = pixbaseclk_video_sync2;
always @(posedge CLK_VIDEO) begin
	pixbaseclk_video_sync1 <= pixbaseclk_select;
	pixbaseclk_video_sync2 <= pixbaseclk_video_sync1;
end

wire 			i2c_din, i2c_dout, i2c_clock;

wire  [5:0] ide_req;
wire  [4:0] ide_address;
wire        ide_write;
wire [15:0] ide_writedata;
wire        ide_read;
wire [15:0] ide_readdata;

wire        fdd_led;
wire        hdd_led;

archimedes_top #(CLKSYS) ARCHIMEDES
(
	.CLKCPU_I	    ( clk_sys        ),
	.CLKPIX_I	    ( CLK_VIDEO      ),
	.CEPIX_I	 	    ( CE_PIXEL       ),
	.CEVID_I         ( CE_VIDC        ),
	.SELPIX_O	    ( selpix         ), 
	.HIRES_MONO_O    ( hires_mono     ),

	.CLKAUD_I	    ( clk_sys        ),
	.CEAUD_I	 	    ( ceaud          ),

	.RESET_I	       ( core_reset          ),
	.RESET_VIDEO_I ( video_reset         ),
	.RESET_VIDEO_CPU_I ( video_reset_request ),
	.RESET_COMMAND_I ( video_command_reset ),

	.MEM_ACK_I	    ( core_ack_in    ),
	.MEM_DAT_I	    ( core_data_in   ),
	.MEM_DAT_O	    ( core_data_out  ),
	.MEM_ADDR_O	    ( core_address_out),
	.MEM_STB_O	    ( core_stb_out   ),
	.MEM_CYC_O	    ( core_cyc_out   ),
	.MEM_SEL_O	    ( core_sel_o     ),
	.MEM_WE_O	    ( core_we_o      ),
	.MEM_CTI_O      ( core_cti_o     ),

	.HSYNC		    ( core_hs        ),
	.VSYNC		    ( core_vs        ),

	.VIDEO_R		    ( core_r         ),
	.VIDEO_G		    ( core_g         ),
	.VIDEO_B		    ( core_b         ),
	.VIDEO_EN       ( core_de        ),

	.AUDIO_L		    ( AUDIO_L        ),
	.AUDIO_R		    ( AUDIO_R        ),

	.I2C_DOUT	    ( i2c_din        ),
	.I2C_DIN		    ( i2c_dout       ),
	.I2C_CLOCK	    ( i2c_clock      ),

	.fdd_led	       ( fdd_led        ),
	.hdd_led	       ( hdd_led        ),

	.sd_lba         ( sd_lba         ),
	.sd_rd          ( sd_rd          ),
	.sd_wr          ( sd_wr          ),
	.sd_ack         ( |sd_ack        ),
	.sd_buff_addr   ( sd_buff_addr   ),
	.sd_buff_dout   ( sd_buff_dout   ),
	.sd_buff_din    ( sd_buff_din    ),
	.sd_buff_wr     ( sd_buff_wr     ),
	.img_mounted    ( img_mounted    ),
	.img_size       ( img_size       ),
	.img_wp         ( img_readonly   ),

	.ide_req        ( ide_req        ),
	.ide_address    ( ide_address    ),
	.ide_write      ( ide_write      ),
	.ide_writedata  ( ide_writedata  ),
	.ide_read       ( ide_read       ),
	.ide_readdata   ( ide_readdata   ),

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

wire [3:0] vmode = {pixbaseclk_video,selpix};

localparam  CLKSYS = 42000000;

reg         cepix_native = 0;
reg         cevid_native = 0;
reg  [2:0]  pixel_count = 0;
wire [2:0]  pixel_divisor = (selpix == 2'd0) ? 3'd6 :
	                            (selpix == 2'd1) ? 3'd4 :
	                            (selpix == 2'd2) ? 3'd3 : 3'd2;
wire [31:0] video_clock_hz = (pixbaseclk_video == 2'd1) ? 32'd50350000 :
	                           (pixbaseclk_video == 2'd2) ? 32'd72000000 :
	                                                                 32'd48000000;
always @(posedge CLK_VIDEO) begin
	if(video_reset) begin
		cepix_native <= 0;
		cevid_native <= 0;
		pixel_count <= 0;
	end else begin
		cepix_native <= 0;
		cevid_native <= 0;
		if(hires_mono) begin
			cepix_native <= 1;
			if(pixel_count == 3) begin
				pixel_count <= 0;
				cevid_native <= 1;
			end else pixel_count <= pixel_count + 1'd1;
		end else if(pixel_count == pixel_divisor - 1'd1) begin
			pixel_count <= 0;
			cepix_native <= 1;
			cevid_native <= 1;
		end
		else pixel_count <= pixel_count + 1'd1;
	end
end

reg         cepix_60 = 0;
reg  [31:0] vclk_60 = 0;
reg  [31:0] vsum_60 = 0;
reg         allow60 = 0;
wire [31:0] vsum_60_next = vsum_60 + vclk_60;
always @(posedge CLK_VIDEO) begin
	if(video_reset) begin
		cepix_60 <= 0;
		vsum_60 <= 0;
	end else begin
		cepix_60 <= 0;
		vsum_60 <= vsum_60_next;
		if(vsum_60_next >= video_clock_hz) begin
			vsum_60 <= vsum_60_next - video_clock_hz;
			cepix_60 <= 1;
		end
	end
end

always @(posedge CLK_VIDEO) begin
	reg [31:0] pixcnt = 0, pix60;
	reg old_sync = 0;

	if(vmode == 7) allow60 <= 1;
	if(video_reset) allow60 <= 0;

	if(video_reset || status[4] || !allow60) vclk_60 <= vratio[vmode];
	else if(CE_PIXEL) begin
		old_sync <= VGA_VS;
		pixcnt <= pixcnt + 1;
		if(~old_sync & VGA_VS) begin
			pix60 <= {pixcnt[26:0],5'd0}+{pixcnt[27:0],4'd0}+{pixcnt[28:0],3'd0}+{pixcnt[29:0],2'd0};
			pixcnt <= 0;
		end
		
		if(pix60<5000000) vclk_60 <= 5000000;
		else if(pix60>video_clock_hz) vclk_60 <= video_clock_hz;
		else vclk_60 <= pix60;
	end
end

assign CE_PIXEL  = (status[4] || !allow60) ? cepix_native : cepix_60;
assign CE_VIDC   = (status[4] || !allow60) ? cevid_native : cepix_60;
assign VGA_F1 = 0;
assign VGA_SL = 0;
assign VGA_SCALER = 0;

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
	.DE_out(vga_de),
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
always @(posedge clk_sys) begin
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

wire        ram_ack;
wire        ram_stb;
wire        ram_cyc;
wire        ram_we;
wire  [3:0]	ram_sel;
wire [25:2] ram_address;
wire        ram_ready;

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

wire riscos_dl = (ioctl_index == 1) && ioctl_download;
wire cmos_dl   = (ioctl_index == 3) && ioctl_download;

reg [21:2] erase_addr;
reg        loader_stb = 0;
always @(posedge clk_sys) begin 
	reg old_dl = 0;

	if(ram_ack) loader_stb <= 0;
	if(riscos_dl & ioctl_wr) loader_stb <= 1;

	old_dl <= riscos_dl;
	if(~old_dl & riscos_dl) begin
		ioctl_wait <= 1;
		erase_addr <= 0;
	end
	
	if(ioctl_wait) begin
		if(ram_ack) begin
			if(~&erase_addr) erase_addr <= erase_addr + 1'd1;
			else ioctl_wait <= 0;
		end
		if(~loader_stb) loader_stb <= 1;
	end
end

assign ram_we      = riscos_dl ? 1'b1 : core_we_o;
assign ram_sel     = riscos_dl ? (ioctl_wait ? 4'b1111 : ioctl_addr[1] ? 4'b1100 : 4'b0011) : core_sel_o;
assign ram_address = riscos_dl ? (ioctl_wait ? erase_addr : {2'b01,ioctl_addr[21:2]}) : core_address_out;
assign ram_stb     = riscos_dl ? loader_stb : core_stb_out;
assign ram_cyc     = riscos_dl ? loader_stb : core_cyc_out;
assign ram_data_in = riscos_dl ? (ioctl_wait ? 32'd0 : {ioctl_dout,ioctl_dout}) : core_data_out;
assign core_ack_in = riscos_dl ? 1'b0 : ram_ack;


//////////////////  RTC/CMOS   ///////////////////
EEPROM_24C0x eeprom
(
   .clk(clk_sys),
	.ce(eep_ce),
	.reset(reset),

   .SCL(i2c_clock),
   .SDA_in(i2c_din),
   .SDA_out(i2c_dout),

   .type_24C01(0),
   .E_id(0),
   .WC_n(0),

   .data_from_ram(eep_dout),
   .data_to_ram(eep_din),
   .ram_addr(eep_addr),
   .ram_read(eep_read),
   .ram_write(eep_write),
   .ram_done(1)
);

wire [7:0] eep_din;
wire [7:0] eep_dout;
wire [7:0] eep_addr;
wire       eep_read;
wire       eep_write;

reg eep_ce;
always @(posedge clk_sys) begin
	reg [1:0] cnt;
	cnt <= cnt + 1'd1;
	eep_ce <= !cnt;
end

reg [7:0] cmos_cnt = 0;
always @(posedge clk_sys) if(eep_ce && eep_write && eep_addr >= 16) cmos_cnt <= cmos_cnt + 1'd1;

dpram_dif #(8,8,7,16,"rtl/cmos.mif") memory
(
	.clock     (clk_sys),

	.address_a (eep_addr),
	.data_a    (eep_din),
	.wren_a    (eep_write),
	.q_a       (eep_dout),

	.address_b (ioctl_addr[7:1]),
	.data_b    (ioctl_dout),
	.wren_b    (ioctl_wr & cmos_dl),
	.q_b       (ioctl_din)
);

endmodule
