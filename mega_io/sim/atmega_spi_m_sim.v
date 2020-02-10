/*
 * This IP is the ATMEGA SPI simulation.
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

`timescale 1ns / 1ps

`define USE_INTERRUPT	"FALSE"

module spi_sim(

	);


reg clk = 1;
reg rst = 1;
always	#(1)	clk	<=	~clk;
reg [5:0]addr = 0;
reg [7:0]bus_in = 0;
wire [7:0]bus_out;
reg wr;
reg rd;
reg ss;
wire dat;
wire int;
reg int_rst;

initial begin
	addr <= 0;
	bus_in <= 8'h00;
	ss <= 1'b1;
	rd <= 1'b0;
	wr <= 1'b0;
	int_rst <= 1'b0;
	wait(clk);
	wait(~clk);
	rst = 1;
	wait(~clk);
	wait(clk);
	#0.1; // Insert real logick delay because, always signals arrive after clock.
	rst = 0;
	#10;
	addr <= 0;
	bus_in <= 8'b11010000;
	wr <= 1'b1;
	#2;
	wr <= 1'b0;
	#10;
	ss <= 1'b0;
	#2;

	addr <= 2;
	bus_in <= 8'haa;
	wr <= 1'b1;
	#2; // Send first byte.
	wr <= 1'b0;
	#2;
	addr <= 1;
	rd <= 1'b1;
	wait(`USE_INTERRUPT == "TRUE" ? int : bus_out[7]); // Wait for byte to be sent.
	rd <= 1'b0;
	#2;
	rd <= 1'b1;
	#2;
	rd <= 1'b0;
	#2;
	if(`USE_INTERRUPT == "TRUE")
	begin
		int_rst <= 1'b1;
		#2;
		int_rst <= 1'b0;
		#6;
	end
	addr <= 2;
	rd <= 1'b1;
	#2; // Read the received byte.
	rd <= 1'b0;
	#2;

	addr <= 2;
	bus_in <= 8'h55;
	wr <= 1'b1;
	#2; // Send second byte.
	wr <= 1'b0;
	#2;
	addr <= 1;
	rd <= 1'b1;
	wait(`USE_INTERRUPT == "TRUE" ? int : bus_out[7]); // Wait for byte to be sent.
	rd <= 1'b0;
	#2;
	rd <= 1'b1;
	#2;
	rd <= 1'b0;
	#2;
	if(`USE_INTERRUPT == "TRUE")
	begin
		int_rst <= 1'b1;
		#2;
		int_rst <= 1'b0;
		#6;
	end
	addr <= 2;
	rd <= 1'b1;
	#2; // Read the received byte.
	rd <= 1'b0;
	#2;



	#10000;
	//sw = 2;
	#10;
	//sw = 0;
	#100000;
	$finish;
end

atmega_spi_m  # (
	.PLATFORM("XILINX"),
	.BUS_ADDR_DATA_LEN(6),
	.SPCR_ADDR(6'h0),
	.SPSR_ADDR(6'h1),
	.SPDR_ADDR(6'h2),
	.DINAMIC_BAUDRATE("TRUE"),
	.BAUDRATE_DIVIDER(0)
)spi_inst(
	.rst(rst),
	.clk(clk),

	.addr(addr),
	.wr(wr),
	.rd(rd),
	.bus_in(bus_in),
	.bus_out(bus_out),
	.int(int),
	.int_rst(int_rst),
	.io_connect(),
	.scl(),
	.miso(dat),
	.mosi(dat)
);
endmodule
