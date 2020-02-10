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
reg data_wr;
reg data_rd;

wire tov_int;
reg tov_int_rst;
wire ocra_int;
reg ocra_int_rst;
wire ocrb_int;
reg ocrb_int_rst;
wire ocrc_int;
reg ocrc_int_rst;
wire ocrd_int;
reg ocrd_int_rst;

wire oca;
wire ocb;
wire occ;
wire ocd;

initial begin
	io_addr = 0;
	io_bus_in = 8'h00;
	io_rd = 1'b0;
	io_wr = 1'b0;
	data_addr = 'h00;
	data_bus_in = 8'h00;
	data_wr = 1'b0;
	data_rd = 1'b0;
	tov_int_rst = 1'b0;
	ocra_int_rst = 1'b0;
	ocrb_int_rst = 1'b0;
	ocrc_int_rst = 1'b0;
	ocrd_int_rst = 1'b0;
	wait(clk);
	wait(~clk);
	rst = 1;
	wait(~clk);
	wait(clk);
	#0.1; // Insert real logick delay because, always signals arrive after clock.
	rst = 0;
	#10;
	data_addr = 'h89; // OCRAH
	data_bus_in = 8'h00;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h88; // OCRAL
	data_bus_in = 8'h7F;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h8B; // OCRBH
	data_bus_in = 8'h00;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h8A; // OCRBL
	data_bus_in = 8'h3F;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h8D; // OCRCH
	data_bus_in = 8'h00;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h8C; // OCRCL
	data_bus_in = 8'h1F;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h8F; // OCRDH
	data_bus_in = 8'h00;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h8E; // OCRDL
	data_bus_in = 8'h0F;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h6F; // TIMSK
	data_bus_in = 8'b00011111;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h80; // TCCRA
	data_bus_in = 8'b10101000;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	data_addr = 'h81; // TCCRB
	data_bus_in = 8'b00001001;
	data_wr = 1'b1;
	#2;
	data_wr = 1'b0;
	#4;
	while(1)
	begin
		if(tov_int)
		begin
			#2;
			tov_int_rst = 1'b1;
			#2;
			tov_int_rst = 1'b0;
		end
		if(ocra_int)
		begin
			#2;
			ocra_int_rst = 1'b1;
			#2;
			ocra_int_rst = 1'b0;
		end
		if(ocrb_int)
		begin
			#2;
			ocrb_int_rst = 1'b1;
			#2;
			ocrb_int_rst = 1'b0;
		end
		if(ocrc_int)
		begin
			#2;
			ocrc_int_rst = 1'b1;
			#2;
			ocrc_int_rst = 1'b0;
		end
		if(ocrd_int)
		begin
			#2;
			ocrd_int_rst = 1'b1;
			#2;
			ocrd_int_rst = 1'b0;
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
atmega_tim_16bit # (
	.PLATFORM("XILINX"),
	.USE_OCRB("TRUE"),
	.USE_OCRC("TRUE"),
	.USE_OCRD("FALSE"),
	.BUS_ADDR_IO_LEN(6),
	.BUS_ADDR_DATA_LEN(8),
	.GTCCR_ADDR('h23),
	.TCCRA_ADDR('h80),
	.TCCRB_ADDR('h81),
	.TCCRC_ADDR('h82),
	.TCCRD_ADDR('h0),
	.TCNTL_ADDR('h84),
	.TCNTH_ADDR('h85),
	.ICRL_ADDR('h86),
	.ICRH_ADDR('h87),
	.OCRAL_ADDR('h88),
	.OCRAH_ADDR('h89),
	.OCRBL_ADDR('h8A),
	.OCRBH_ADDR('h8B),
	.OCRCL_ADDR('h8C),
	.OCRCH_ADDR('h8D),
	.OCRDL_ADDR('h0),
	.OCRDH_ADDR('h0),
	.TIMSK_ADDR('h6F),
	.TIFR_ADDR('h16),
	.DINAMIC_BAUDRATE("TRUE"),
	.BAUDRATE_DIVIDER(1)
)tim_1_sim(
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
	.ocrc_int(ocrc_int),
	.ocrc_int_rst(ocrc_int_rst),
	.ocrd_int(ocrd_int),
	.ocrd_int_rst(ocrd_int_rst),
	
	.t(),
	.oca(oca),
	.ocb(ocb),
	.occ(occ),
	.ocd(ocd),
	.oca_io_connect(),
	.ocb_io_connect(),
	.occ_io_connect(),
	.ocd_io_connect()
	);

endmodule
