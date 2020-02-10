/*
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

`timescale 1ns / 1ps


module atmega_pll_sim(

    );

reg clk = 1;
reg rst = 1;
reg clk_pll = 1;
always	#(5)	clk	<=	~clk;
always	#(2.6)	clk_pll	<=	~clk_pll;
reg [5:0]addr = 0;
reg [7:0]bus_in = 0;
wire [7:0]bus_out;
reg wr;
reg rd;
reg ss;
wire dat;
wire usb_ck_out;
wire tim_ck_out;

initial begin
	addr <= 0;
	bus_in <= 8'h00;
	rd <= 1'b0;
	wr <= 1'b0;
	rst <= 1'b0;
	wait(clk);
	wait(~clk);
	rst = 1;
	wait(~clk);
	wait(clk);
	#0.1; // Insert real logick delay because, always signals arrive after clock.
	rst = 0;
	#10;
	addr <= 6'h32;
	bus_in <= 8'b00001010;
	wr <= 1'b1;
	#10;
	wr <= 1'b0;
	#10;
end

atmega_pll # (
	.PLATFORM("XILINX"),
	.BUS_ADDR_DATA_LEN(6),
	.PLLCSR_ADDR('h29),
	.PLLFRQ_ADDR('h32)
)pll(
	.rst(rst),
	.clk(clk),
	.clk_pll(clk_pll),
	.addr(addr),
	.wr(wr),
	.rd(rd),
	.bus_in(bus_in),
	.bus_out(bus_out),

	.usb_ck_out(usb_ck_out),
	.tim_ck_out(tim_ck_out)
	);

endmodule
