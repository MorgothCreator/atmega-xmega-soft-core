/*
 * This IP is the ATMEGA 8bit TIMER simulation.
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


module atmega_tim_8bit_sim(

    );

reg clk = 1;
reg rst = 1;
always	#(1)	clk	<=	~clk;
reg [5:0]io_addr = 0;
reg [7:0]io_bus_in = 0;
reg io_wr;
reg io_rd;

reg [7:0]data_addr = 0;
reg [7:0]data_bus_in = 0;
wire [7:0]data_bus_out;
reg data_wr;
reg data_rd;

wire tov_int;
reg tov_int_rst;
wire ocra_int;
reg ocra_int_rst;
wire ocrb_int;
reg ocrb_int_rst;

wire oca;
wire ocb;

initial begin
	io_addr <= 0;
	io_bus_in <= 8'h00;
	io_rd <= 1'b0;
	io_wr <= 1'b0;
	tov_int_rst <= 1'b0;
	ocra_int_rst <= 1'b0;
	ocrb_int_rst <= 1'b0;
	wait(clk);
	wait(~clk);
	rst = 1;
	wait(~clk);
	wait(clk);
	#0.1; // Insert real logick delay because, always signals arrive after clock.
	rst = 0;
	#10;
	io_addr <= 'h27; // OCRA
	io_bus_in <= 8'h1F;
	io_wr <= 1'b1;
	#2;
	io_wr <= 1'b0;
	#4;
	io_addr <= 'h28; // OCRB
	io_bus_in <= 8'h0F;
	io_wr <= 1'b1;
	#2;
	io_wr <= 1'b0;
	#4;
	data_addr <= 'h6E; // TIMSK
	data_bus_in <= 8'b00000111;
	data_wr <= 1'b1;
	#2;
	data_wr <= 1'b0;
	#4;
	io_addr <= 'h24; // TCCRA
	io_bus_in <= 8'b10100001;
	io_wr <= 1'b1;
	#2;
	io_wr <= 1'b0;
	#4;
	io_addr <= 'h25; // TCCRB
	io_bus_in <= 8'b00000010;
	io_wr <= 1'b1;
	#2;
	io_wr <= 1'b0;
	#4;
	while(1)
	begin
		if(tov_int)
		begin
			#2;
			tov_int_rst <= 1'b1;
			#2;
			tov_int_rst <= 1'b0;
		end
		if(ocra_int)
		begin
			#2;
			ocra_int_rst <= 1'b1;
			#2;
			ocra_int_rst <= 1'b0;
		end
		if(ocrb_int)
		begin
			#2;
			ocrb_int_rst <= 1'b1;
			#2;
			ocrb_int_rst <= 1'b0;
		end
		#2;
	end
end



wire clk8;
wire clk64;
wire clk256;
wire clk1024;
tim_013_prescaller tim_013_prescaller_inst(
	.rst(rst),
	.clk(clk),
	.clk8(clk8),
	.clk64(clk64),
	.clk256(clk256),
	.clk1024(clk1024)
);



wire [7:0]io_tim0_d_out;
wire [7:0]dat_tim0_d_out;
atmega_tim_8bit # (
	.PLATFORM("XILINX"),
	.USE_OCRB("TRUE"),
	.BUS_ADDR_IO_LEN(6),
	.BUS_ADDR_DATA_LEN(8),
	.GTCCR_ADDR('h23),
	.TCCRA_ADDR('h24),
	.TCCRB_ADDR('h25),
	.TCNT_ADDR('h26),
	.OCRA_ADDR('h27),
	.OCRB_ADDR('h28),
	.TIMSK_ADDR('h6E),
	.TIFR_ADDR('h15),
	.DINAMIC_BAUDRATE("TRUE"),
	.BAUDRATE_DIVIDER(1)
)tim_0_sim(
	.rst(rst),
	.clk(clk),
	.clk8(clk8),
	.clk64(clk64),
	.clk256(clk256),
	.clk1024(clk1024),
	.addr_io(io_addr),
	.wr_io(io_wr),
	.rd_io(io_rd),
	.bus_io_in(io_bus_in),
	.bus_io_out(io_tim0_d_out),
	.addr_dat(data_addr[7:0]),
	.wr_dat(data_wr),
	.rd_dat(data_rd),
	.bus_dat_in(data_bus_in),
	.bus_dat_out(dat_tim0_d_out),
	.tov_int(tov_int),
	.tov_int_rst(tov_int_rst),
	.ocra_int(ocra_int),
	.ocra_int_rst(ocra_int_rst),
	.ocrb_int(ocrb_int),
	.ocrb_int_rst(ocrb_int_rst),
	
	.t(),
	.oca(oca),
	.ocb(ocb),
	.oca_io_connect(),
	.ocb_io_connect()
	);

endmodule
