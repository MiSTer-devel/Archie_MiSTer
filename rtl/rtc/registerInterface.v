//////////////////////////////////////////////////////////////////////
////                                                              ////
//// registerInterface.v                                          ////
////                                                              ////
//// This file is part of the i2cSlave opencores effort.
//// <http://www.opencores.org/cores//>                           ////
////                                                              ////
//// Module Description:                                          ////
//// You will need to modify this file to implement your 
//// interface.
//// Add your control and status bytes/bits to module inputs and outputs,
//// and also to the I2C read and write process blocks  
////                                                              ////
//// To Do:                                                       ////
//// 
////                                                              ////
//// Author(s):                                                   ////
//// - Steve Fielding, sfielding@base2designs.com                 ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2008 Steve Fielding and OPENCORES.ORG          ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from <http://www.opencores.org/lgpl.shtml>                   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//

module registerInterface
(
	input 	    clk,
	input  [7:0] addr,
	input  [7:0] dataIn,
	input 	    writeEn,
	output reg [7:0] dataOut,
	input [64:0] RTC
);

wire [7:0] mem_out;
spram #(8,8,"rtl/rtc/cmos.mif","CMOS") memory
(
	.clock(clk),
	.address(addr),
	.data(dataIn),
	.wren(writeEn),
	.q(mem_out)
);

wire [7:0] year = {3'b000,RTC[47:44],1'b0} + {RTC[47:44],3'b000} + RTC[43:40];

// --- I2C Read
always @(*) begin
  casex (addr)
    8'h02: dataOut = RTC[7:0];   // secs
    8'h03: dataOut = RTC[15:8];  // mins
    8'h04: dataOut = RTC[23:16]; // hour
    8'h05: dataOut = {year[1:0],RTC[29:24]}; // date
    8'h06: dataOut = {RTC[50:48],RTC[36:32]}; // weekday/month
	 8'hC0: dataOut = year;
	 8'hC1: dataOut = 20;
    8'b0000000X,
    8'b00000111,
    8'b00001XXX: dataOut = 0;
    default: dataOut = mem_out;
  endcase
end

endmodule


 
