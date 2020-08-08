`timescale 1ns / 1ps
/* vidc_dmachannel.v

 Copyright (c) 2012-2015, Stephen J. Leary
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
module vidc_dmachannel
(
	input         clkcpu,
	input         clkdev,
	input         cedev,

	input         rst,
		
	// dma bus
	input         ak,
	output reg    rq,
	input [31:0]  cpu_data,
	
	input         stall, // dont start another request with this high.
	
	// device bus
	input         dev_ak,
	output  [7:0] dev_data
);

parameter FIFO_SIZE = 3;

// each channel has a fifo of a different size. 
wire [FIFO_SIZE-1:0]	space;
wire full;

initial begin 
	rq	= 0;
end

vidc_fifo #(.FIFO_SIZE(FIFO_SIZE)) VIDEO_FIFO
(
	.rst    ( rst      ),
	.wr_clk ( clkcpu   ),
	.rd_clk ( clkdev   ),
	.rd_ce  ( cedev    ),
	.wr_en  ( ak & rq  ),
	.rd_en  ( dev_ak   ),

	.din    ( cpu_data ),
	.dout   ( dev_data ),

	.space  ( space    ),
	.full   ( full     )
);

// DMA interface control
// this is in the cpu clock domain. 
always @(posedge clkcpu) begin : block
	reg [1:0] dma_count;
	reg rstD, rstD2;

	rstD <= rst;
	rstD2 <= rstD;

	if (rstD2) begin
		// do reset logic 
		dma_count <= 0;	
		rq        <= 0;
	end
	else if(rq) begin
		if (ak) begin
			dma_count <= dma_count + 1'd1;
			if (&dma_count) rq <= 0;
		end
	end
	// Start DMA only if there is a space at least for 4 items
	// DMA uses burst with 4 items (8 SDRAM reads)
	else if(~stall & ((space>=4) | (!space & !full))) begin
		dma_count <= 0;
		rq <= 1;
	end
end

endmodule
