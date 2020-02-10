/*
 * This IP is the ATMEGA PIO implementation.
 * 
 * Copyright (C) 2020  Iulian Gheorghiu (morgoth@devboard.tech)
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
 
/************************************************************/
/* Atention!  This file contain platform dependent modules. */
/************************************************************/

`timescale 1ns / 1ps


module atmega_pio # (
	parameter PLATFORM = "XILINX",
	parameter BUS_ADDR_IO_LEN = 16,
	parameter PORT_ADDR = 0,
	parameter DDR_ADDR = 1,
	parameter PIN_ADDR = 2,
	parameter PINMASK = 8'hFF,
	parameter PULLUP_MASK = 8'h0,
	parameter PULLDN_MASK = 8'h0,
	parameter INVERSE_MASK = 8'h0,
	parameter OUT_ENABLED_MASK = 8'hFF
)(
	input rst,
	input clk,
	input [BUS_ADDR_IO_LEN-1:0]addr,
	input wr,
	input rd,
	input [7:0]bus_in,
	output reg [7:0]bus_out,

	input [7:0]io_in,
	output [7:0]io_out,
	output [7:0]pio_out_io_connect,
	output [4:0]debug
	);

reg [7:0]DDR;
reg [7:0]PORT;
reg [7:0]PIN;

assign debug = PIN[7:3];
assign pio_out_io_connect = DDR;

always @ (posedge rst or posedge clk)
begin
	if(rst)
	begin
		DDR <= 8'h00;
		PORT <= 8'h00;
		PIN <=  8'h00;
	end
	else
	begin
		PIN <= io_in;
		if(wr)
		begin
			case(addr)
			DDR_ADDR: DDR <= bus_in;
			PORT_ADDR: PORT <= bus_in;
			endcase
		end
	end
end

integer cnt_;

always @ *
begin
	bus_out = 8'h00;
	if(rd & ~rst)
	begin
		case(addr)
		PORT_ADDR: bus_out = PORT;
		DDR_ADDR: bus_out = DDR;
		PIN_ADDR: 
		begin
			for(cnt_ = 0; cnt_ < 8; cnt_ = cnt_ + 1)
			begin
				if (PINMASK[cnt_])
				begin
					bus_out[cnt_] = INVERSE_MASK[cnt_] ? ~PIN[cnt_] : PIN[cnt_];
				end
			end
		end
		endcase
	end
end

genvar cnt;
generate

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:OUTS
	if (PINMASK[cnt] && OUT_ENABLED_MASK[cnt])
	begin
		assign io_out[cnt] = DDR[cnt] ? (INVERSE_MASK[cnt] ? ~PORT[cnt] : PORT[cnt]) : 1'bz;
	end
	else
	begin
		assign io_out[cnt] = 1'bz;
	end
end

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:PULLUPS
	if (PULLUP_MASK[cnt] && PINMASK[cnt])
	begin
		if (PLATFORM == "XILINX")
		begin
			PULLUP PULLUP_inst (
				.O(io_out[cnt])     // PullUp output (connect directly to top-level port)
			);
		end
	end
end

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:PULLDOWNS
	if (PULLDN_MASK[cnt] && PINMASK[cnt])
	begin
		if (PLATFORM == "XILINX")
		begin
			PULLDOWN PULLDOWN_inst (
				.O(io_out[cnt])     // PullDown output (connect directly to top-level port)
			);
		end
	end
end

endgenerate


endmodule
