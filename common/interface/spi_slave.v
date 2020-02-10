/*
 * This IP is the SPI slave implementation.
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


module spi_slave # (
	parameter MAX_BITS_PER_WORD = 8
	)(
	input rst,
	input clk,
	input en,
	input [3:0]bit_per_word,
	input lsb_first,
	input ss,
	input scl,
	output miso,
	input mosi,
	input [MAX_BITS_PER_WORD - 1:0]bus_in,
	output reg rdy,
	input rdy_ack,
	output reg [MAX_BITS_PER_WORD - 1:0]bus_out,
	output first_byte,
	output last_byte,
	input last_byte_ack
	);

reg [MAX_BITS_PER_WORD - 1:0]rx_shift_reg;
reg [MAX_BITS_PER_WORD - 1:0]tx_shift_reg;
reg [3:0]bit_cnt;
reg first_byte_1;
reg first_byte_2;

reg rdy_p;
reg rdy_n;

reg last_byte_p;
reg last_byte_n;

reg cs_p;
reg cs_start_p;

reg [3:0]bit_per_word_int;

always @ (posedge rst or posedge clk)
begin
	if(rst | ~en)
	begin
		rdy_n <= 'h0;
	end
	else
	if(rdy_ack)
	begin
		rdy_n <= rdy_p;
	end
end

always @ (posedge rst or posedge clk)
begin
	if(rst | ~en)
	begin
		last_byte_n <= 1'b0;
	end
	else
	if(last_byte_ack)
	begin
		last_byte_n <= last_byte_p;
	end
end

always @ (posedge rst or posedge clk)
begin
	if(rst | ~en)
	begin
		last_byte_p <= 1'b0;
		cs_p <= 1'b1;
	end
	else
	begin
		if(last_byte_p == last_byte_n && {cs_p, ss} == 2'b01)
		begin
			last_byte_p <= ~last_byte_p;
		end
		cs_p <= ss;
	end
end

//rx
always @ (posedge rst or posedge scl or posedge ss)
begin
	if(rst | ~en)
	begin
		rx_shift_reg <= 'hFFF;
		bit_cnt <= 4'h0;
		first_byte_1 <= 1'b0;
		first_byte_2 <= 1'b0;
		rdy_p <= 1'b0;
		bit_per_word_int <= bit_per_word - 4'd1;
		bus_out <= 8'h00;
	end
	else
	begin
		if(ss)
		begin
			rx_shift_reg <= 'hFFF;
			bit_cnt <= 4'h0;
			first_byte_1 <= 1'b0;
			first_byte_2 <= 1'b0;
			bit_per_word_int <= bit_per_word - 4'd1;
		end
		else
		begin
			bit_cnt <= bit_cnt + 4'd1;
			if(bit_cnt == bit_per_word_int)
			begin
				first_byte_2 <= first_byte_1;
				first_byte_1 <= 1'b1;
				if(rdy_p == rdy_n)
				begin
					rdy_p <= ~rdy_p;
				end
				if(lsb_first == 1'b0)
				begin
					bus_out <= {rx_shift_reg[MAX_BITS_PER_WORD - 2:0], mosi};
				end
				else
				begin
					bus_out <= rx_shift_reg[MAX_BITS_PER_WORD - 1:0];
					bus_out[bit_cnt] <= mosi;
				end
				bit_cnt <= 4'h0;
			end
			if(lsb_first == 1'b0)
			begin
				rx_shift_reg <= {rx_shift_reg[MAX_BITS_PER_WORD - 2:0], mosi};
			end
			else
			begin
				rx_shift_reg[bit_cnt] <= mosi;
			end
		end
	end
end
//tx
always @ (posedge rst or negedge scl or posedge ss)
begin
	if(rst | ~en)
	begin
		tx_shift_reg <= 'h0;
	end
	else
	begin
		if(bit_cnt == 4'h0 || ss)
		begin
			tx_shift_reg <= bus_in;
		end
		else
		begin
			if(lsb_first == 1'b0)
			begin
				tx_shift_reg <= {tx_shift_reg[MAX_BITS_PER_WORD - 2:0], 1'b0};
			end
			else
			begin
				tx_shift_reg <= {1'b0, tx_shift_reg[MAX_BITS_PER_WORD - 1:1]};
			end
		end
	end
end

always @ (posedge rst or posedge clk)
begin
	if(rst)
	begin
		rdy <= 1'b0;
	end
	else
	begin
		rdy <= rdy_p ^ rdy_n;
	end
end

assign miso = (ss | ~en) ? 1'bz : (lsb_first == 1'b0 ? tx_shift_reg[bit_per_word_int] : tx_shift_reg[0]);
assign first_byte = first_byte_1 & ~first_byte_2;
assign last_byte = last_byte_n ^ last_byte_p;

endmodule