// Select the native parent clock for each normal VIDC base-clock family.
module video_pll_profile (
	input  wire        clk,
	input  wire        reset,
	input  wire [1:0]  desired_profile,
	output reg         busy,
	output reg         write,
	output reg  [5:0]  address,
	output reg  [31:0] writedata,
	input  wire        waitrequest
);
	localparam [5:0] M_REG     = 6'd4;
	localparam [5:0] C_REG     = 6'd5;
	localparam [5:0] DSM_REG   = 6'd7;
	localparam [5:0] START_REG = 6'd2;

	// Parent profiles:
	//   0: 50 * (11 + 0.52)  / 12 = 48.000 MHz
	//   1: 50 * (12 + 0.084) / 12 = 50.350 MHz
	//   2: 50 * (11 + 0.52)  /  8 = 72.000 MHz
	//   3: 50 * (11 + 0.52)  /  6 = 96.000 MHz (Mode 23 serializer)
	localparam [31:0] M_48  = 32'h0002_0605;
	localparam [31:0] K_48  = 32'd2233382994;
	localparam [31:0] M_VGA = 32'h0000_0606;
	localparam [31:0] K_VGA = 32'd360777253;
	localparam [31:0] C_12  = 32'h0000_0606;
	localparam [31:0] C_8   = 32'h0000_0404;
	localparam [31:0] C_6   = 32'h0000_0303;

	localparam [2:0] BOOT_WAIT = 3'd0, IDLE = 3'd1, WRITE_M = 3'd2,
	                 WRITE_K = 3'd3, WRITE_C = 3'd4, START = 3'd5,
	                 SETTLE = 3'd6;
	reg [2:0]  state;
	reg [1:0]  active_profile;
	reg [1:0]  target_profile;
	reg [12:0] settle_count;

	always @(posedge clk) begin
		if(reset) begin
			state          <= BOOT_WAIT;
			active_profile <= 2'd3;
			target_profile <= 2'd3;
			busy           <= 1'b1;
			write          <= 1'b0;
			address        <= 6'd0;
			writedata      <= 32'd0;
			settle_count   <= 13'd0;
		end else begin
			case(state)
				BOOT_WAIT: begin
					if(settle_count == 13'h1fff) begin
						settle_count <= 13'd0;
						state <= IDLE;
						busy <= 1'b0;
					end else settle_count <= settle_count + 1'd1;
				end
				IDLE: if(desired_profile != active_profile) begin
					target_profile <= desired_profile;
					busy <= 1'b1;
					state <= ((desired_profile == 2'd1) !=
					          (active_profile == 2'd1)) ? WRITE_M : WRITE_C;
				end
				WRITE_M: begin
					if(!write) begin
						write <= 1'b1;
						address <= M_REG;
						writedata <= (target_profile == 2'd1) ? M_VGA : M_48;
					end else if(!waitrequest) begin
						write <= 1'b0;
						state <= WRITE_K;
					end
				end
				WRITE_K: begin
					if(!write) begin
						write <= 1'b1;
						address <= DSM_REG;
						writedata <= (target_profile == 2'd1) ? K_VGA : K_48;
					end else if(!waitrequest) begin
						write <= 1'b0;
						state <= WRITE_C;
					end
				end
				WRITE_C: begin
					if(!write) begin
						write <= 1'b1;
						address <= C_REG;
						writedata <= (target_profile == 2'd3) ? C_6 :
						             (target_profile == 2'd2) ? C_8 : C_12;
					end else if(!waitrequest) begin
						write <= 1'b0;
						state <= START;
					end
				end
				START: begin
					if(!write) begin
						write <= 1'b1;
						address <= START_REG;
						writedata <= 32'd1;
					end else if(!waitrequest) begin
						write <= 1'b0;
						active_profile <= target_profile;
						settle_count <= 13'd0;
						state <= SETTLE;
					end
				end
				SETTLE: begin
					if(settle_count == 13'h1fff) begin
						state <= IDLE;
						busy <= 1'b0;
					end else settle_count <= settle_count + 1'd1;
				end
				default: state <= BOOT_WAIT;
			endcase
		end
	end
endmodule
