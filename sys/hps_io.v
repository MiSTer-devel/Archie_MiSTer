//
// hps_io.v (Archie only)
//
// mist_io-like module for the Terasic DE10 board
//
// Copyright (c) 2014 Till Harbaum <till@harbaum.org>
// Copyright (c) 2017 Sorgelig (port to DE10-nano)
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

//
// Use buffer to access SD card. It's time-critical part.
//

// WIDE=1 for 16 bit file I/O
// VDNUM 1-4
module hps_io #(parameter STRLEN=0, WIDE=0, VDNUM=1)
(
	input             clk_sys,
	inout      [43:0] HPS_BUS,

	// parameter STRLEN and the actual length of conf_str have to match
	input [(8*STRLEN)-1:0] conf_str,

	output reg [15:0] joystick_0,
	output reg [15:0] joystick_1,
	output reg [15:0] joystick_analog_0,
	output reg [15:0] joystick_analog_1,

	output      [1:0] buttons,
	output            forced_scandoubler,

	output reg [31:0] status,

	// SD config
	output reg [VD:0] img_mounted,  // signaling that new image has been mounted
	output reg        img_readonly, // mounted as read only. valid only for active bit in img_mounted
	output reg [63:0] img_size,     // size of image in bytes. valid only for active bit in img_mounted

	// SD block level access
	input      [31:0] sd_lba,
	input      [VD:0] sd_rd,       // only single sd_rd can be active at any given time
	input      [VD:0] sd_wr,       // only single sd_wr can be active at any given time
	output reg        sd_ack,
	
	// do not use in new projects.
	// CID and CSD are fake except CSD image size field.
	input             sd_conf,
	output reg        sd_ack_conf,

	// SD byte level access. Signals for 2-PORT altsyncram.
	output reg [AW:0] sd_buff_addr,
	output reg [DW:0] sd_buff_dout,
	input      [DW:0] sd_buff_din,
	output reg        sd_buff_wr,

	// ARM -> FPGA download
	output reg        ioctl_download = 0, // signal indicating an active download
	output      [3:0] ioctl_sel, 
	output reg        ioctl_wr,
	output reg [24:0] ioctl_addr,         // in WIDE mode address will be incremented by 2
	output     [31:0] ioctl_dout,
	input             ioctl_wait,

	input      [31:0] fdc_status_out,
	output reg [31:0] fdc_status_in,
	output reg        fdc_data_in_strobe,
	output reg  [7:0] fdc_data_in,

	// RTC MSM6242B layout
	output reg [63:0] RTC,

	input       [7:0] kbd_out_data,
	input             kbd_out_strobe,
	output reg  [7:0] kbd_in_data,
	output reg        kbd_in_strobe
);

localparam DW = (WIDE) ? 15 : 7;
localparam AW = (WIDE) ?  7 : 8;
localparam VD = VDNUM-1;

wire        io_wait  = ioctl_wait;
wire        io_enable= |HPS_BUS[35:34];
wire        io_strobe= HPS_BUS[33];
wire        io_wide  = (WIDE) ? 1'b1 : 1'b0;
wire [15:0] io_din   = HPS_BUS[31:16];
reg  [15:0] io_dout;

assign HPS_BUS[37]   = io_wait;
assign HPS_BUS[36]   = clk_sys;
assign HPS_BUS[32]   = io_wide;
assign HPS_BUS[15:0] = io_dout;

reg [7:0] cfg;
assign buttons = cfg[1:0];
//cfg[2] - vga_scaler handled in sys_top
//cfg[3] - csync handled in sys_top
assign forced_scandoubler = cfg[4];
//cfg[5] - ypbpr handled in sys_top

// command byte read by the io controller
wire [15:0] sd_cmd = 
{
	2'b00,
	(VDNUM>=4) ? sd_wr[3] : 1'b0,
	(VDNUM>=3) ? sd_wr[2] : 1'b0,
	(VDNUM>=2) ? sd_wr[1] : 1'b0,

	(VDNUM>=4) ? sd_rd[3] : 1'b0,
	(VDNUM>=3) ? sd_rd[2] : 1'b0,
	(VDNUM>=2) ? sd_rd[1] : 1'b0,
	
	4'h5, sd_conf, 1'b1,
	sd_wr[0],
	sd_rd[0]
};

///////////////// calc video parameters //////////////////

wire clk_100 = HPS_BUS[43];
wire clk_vid = HPS_BUS[42];
wire ce_pix  = HPS_BUS[41];
wire de      = HPS_BUS[40];
wire hs      = HPS_BUS[39];
wire vs      = HPS_BUS[38];

reg [31:0] vid_hcnt = 0;
reg [31:0] vid_vcnt = 0;
reg  [7:0] vid_nres = 0;
integer hcnt;

always @(posedge clk_vid) begin
	integer vcnt;
	reg old_vs= 0, old_de = 0;
	reg calch = 0;

	if(ce_pix) begin
		old_vs <= vs;
		old_de <= de;

		if(~vs & ~old_de & de) vcnt <= vcnt + 1;
		if(calch & de) hcnt <= hcnt + 1;
		if(old_de & ~de) calch <= 0;

		if(old_vs & ~vs) begin
			if(hcnt && vcnt) begin
				if(vid_hcnt != hcnt || vid_vcnt != vcnt) vid_nres <= vid_nres + 1'd1;
				vid_hcnt <= hcnt;
				vid_vcnt <= vcnt;
			end
			vcnt <= 0;
			hcnt <= 0;
			calch <= 1;
		end
	end
end

reg [31:0] vid_htime = 0;
reg [31:0] vid_vtime = 0;
reg [31:0] vid_pix = 0;

always @(posedge clk_100) begin
	integer vtime, htime, hcnt;
	reg old_vs, old_hs, old_vs2, old_hs2, old_de, old_de2;
	reg calch = 0;

	old_vs <= vs;
	old_hs <= hs;

	old_vs2 <= old_vs;
	old_hs2 <= old_hs;

	vtime <= vtime + 1'd1;
	htime <= htime + 1'd1;

	if(~old_vs2 & old_vs) begin
		vid_pix <= hcnt;
		vid_vtime <= vtime;
		vtime <= 0;
		hcnt <= 0;
	end

	if(old_vs2 & ~old_vs) calch <= 1;

	if(~old_hs2 & old_hs) begin
		vid_htime <= htime;
		htime <= 0;
	end

	old_de   <= de;
	old_de2  <= old_de;

	if(calch & old_de) hcnt <= hcnt + 1;
	if(old_de2 & ~old_de) calch <= 0;
end

/////////////////////////////////////////////////////////

always@(posedge clk_sys) begin
	reg [15:0] cmd;
	reg  [9:0] byte_cnt;   // counts bytes
	reg  [2:0] b_wr;
	reg  [2:0] stick_idx;
	
	reg  old_out_strobe = 0;
	reg  kbd_out_data_available = 0;    

	sd_buff_wr <= b_wr[0];
	if(b_wr[2] && (~&sd_buff_addr)) sd_buff_addr <= sd_buff_addr + 1'b1;
	b_wr <= (b_wr<<1);

	kbd_in_strobe <= 0;
	old_out_strobe <= kbd_out_strobe;
	if(~old_out_strobe && kbd_out_strobe) kbd_out_data_available <= 1;
	
	fdc_data_in_strobe <= 0;

	if(~io_enable) begin
		cmd <= 0;
		byte_cnt <= 0;
		sd_ack <= 0;
		sd_ack_conf <= 0;
		io_dout <= 0;
	end else begin
		if(io_strobe) begin

			io_dout <= 0;
			if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;

			if(byte_cnt == 0) begin
				cmd <= io_din;

				case(io_din)
					'h19: sd_ack_conf <= 1;
					'h17,
					'h18: sd_ack <= 1;
				endcase

				sd_buff_addr <= 0;
				img_mounted <= 0;
			end else begin

				case(cmd)
					// buttons and switches
					'h01: cfg        <= io_din[7:0]; 
					'h02: joystick_0 <= io_din;
					'h03: joystick_1 <= io_din;

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

					// reading config string
					'h14: begin
							// returning a byte from string
							if(byte_cnt < STRLEN + 1) io_dout[7:0] <= conf_str[(STRLEN - byte_cnt)<<3 +:8];
						end

					// reading sd card status
					'h16: begin
							case(byte_cnt)
								1: io_dout <= sd_cmd;
								2: io_dout <= sd_lba[15:0];
								3: io_dout <= sd_lba[31:16];
							endcase
						end

					// send SD config IO -> FPGA
					// flag that download begins
					// sd card knows data is config if sd_dout_strobe is asserted
					// with sd_ack still being inactive (low)
					'h19,
					// send sector IO -> FPGA
					// flag that download begins
					'h17: begin
							sd_buff_dout <= io_din[DW:0];
							b_wr <= 1;
						end

					// reading sd card write data
					'h18: begin
							if(~&sd_buff_addr) sd_buff_addr <= sd_buff_addr + 1'b1;
							io_dout <= sd_buff_din;
						end

					// joystick analog
					'h1a: begin
							// first byte is joystick index
							if(byte_cnt == 1) stick_idx <= io_din[2:0];
							if(byte_cnt == 2) begin
								if(stick_idx == 0) joystick_analog_0 <= io_din;
								if(stick_idx == 1) joystick_analog_1 <= io_din;
							end
						end

					// notify image selection
					'h1c: begin
							img_mounted  <= io_din[VD:0] ? io_din[VD:0] : 1'b1;
							img_readonly <= io_din[7];
						end

					// send image info
					'h1d: if(byte_cnt<5) img_size[{byte_cnt-1'b1, 4'b0000} +:16] <= io_din;

					// status, 32bit version
					'h1e: if(byte_cnt==1) status[15:0] <= io_din;
								else if(byte_cnt==2) status[31:16] <= io_din;

					//RTC
					'h22: RTC[(byte_cnt-6'd1)<<4 +:16] <= io_din;

					//Video res.
					'h23: begin
								case(byte_cnt)
									1: io_dout <= vid_nres;
									2: io_dout <= vid_hcnt[15:0];
									3: io_dout <= vid_hcnt[31:16];
									4: io_dout <= vid_vcnt[15:0];
									5: io_dout <= vid_vcnt[31:16];
									6: io_dout <= vid_htime[15:0];
									7: io_dout <= vid_htime[31:16];
									8: io_dout <= vid_vtime[15:0];
									9: io_dout <= vid_vtime[31:16];
								  10: io_dout <= vid_pix[15:0];
								  11: io_dout <= vid_pix[31:16];
								endcase
						end

					'h55: //ARCHIE_FDC_GET_STATUS:
						begin
							if(byte_cnt == 1) io_dout[7:0] <= fdc_status_out[31:24];
							if(byte_cnt == 2) io_dout[7:0] <= fdc_status_out[23:16];
							if(byte_cnt == 3) io_dout[7:0] <= fdc_status_out[15:8];
							if(byte_cnt == 4) io_dout[7:0] <= fdc_status_out[7:0];
						end

					'h56: //ARCHIE_FDC_TX_DATA:
						begin
							fdc_data_in_strobe <= 1;
							fdc_data_in <= io_din[7:0];
						end

					'h57: //ARCHIE_FDC_SET_STATUS:
						begin
							if(byte_cnt == 1) fdc_status_in[31:24] <= io_din[7:0];
							if(byte_cnt == 2) fdc_status_in[23:16] <= io_din[7:0];
							if(byte_cnt == 3) fdc_status_in[15:8]  <= io_din[7:0];
							if(byte_cnt == 4) fdc_status_in[7:0]   <= io_din[7:0];
						end
				endcase
			end
		end
	end
end

///////////////////////////////   DOWNLOADING   ///////////////////////////////

localparam UIO_FILE_TX         = 8'h53;
localparam UIO_FILE_TX_DAT     = 8'h54;

assign ioctl_sel  = ioctl_addr[1] ? 4'b1100 : 4'b0011;
assign ioctl_dout = {data,data};

reg [15:0] data;

always@(posedge clk_sys) begin
	reg [15:0] cmd;
	reg        has_cmd;
	reg [24:0] addr;
	reg        wr;

	ioctl_wr <= wr;
	wr <= 0;
	
	if(~io_enable) has_cmd <= 0;
	else begin
		if(io_strobe) begin

			if(!has_cmd) begin
				cmd <= io_din;
				has_cmd <= 1;
			end else begin

				case(cmd)
					UIO_FILE_TX:
						begin
							if(io_din[7:0]) begin
								addr <= 25'h400000;
								ioctl_download <= 1; 
							end else begin
								ioctl_addr <= addr;
								ioctl_download <= 0;
							end
						end

					UIO_FILE_TX_DAT:
						begin
							ioctl_addr <= addr;
							data <= io_din;
							wr   <= 1;
							addr <= addr + 2'd2;
						end
				endcase
			end
		end
	end
end

endmodule

