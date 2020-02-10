/*
 * This IP is the RTC timmer implementation.
 * 
 * Copyright (C) 2018  Iulian Gheorghiu (morgoth@devboard.tech)
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

`include "io_s_h.v"

module rtc_s #(
	parameter PERIOD_STATIC = 0,
	parameter ADDRESS = 0,
	parameter BUS_ADDR_DATA_LEN = 16,
	parameter CNT_SIZE = 10
	)(
	input rst,
	input clk,
	input [BUS_ADDR_DATA_LEN-1:0]addr,
	input wr,
	input rd,
	input [7:0]bus_in,
	output reg[7:0]bus_out,
	output req_bus,
	output reg int,
	input int_rst
	);

assign req_bus = addr >= ADDRESS && addr < (ADDRESS + 8);
wire rd_int = req_bus && rd;
wire wr_int = req_bus && wr;
reg int_rst_int;
reg int_rst_int_n;

reg [CNT_SIZE > 8 ? (CNT_SIZE-1-8) : 0:0]CNT_IO;
reg [CNT_SIZE-1:0]cnt;
reg [CNT_SIZE > 8 ? (CNT_SIZE-1-8) : 0:0]PERIOD_IO;
reg [CNT_SIZE-1:0]PERIOD;

always @ (posedge int_rst or posedge rst)
begin
	if(rst)
		int_rst_int <= 'h0;
	else if(int_rst_int == int_rst_int_n)
		int_rst_int <= ~int_rst_int;
end

always @ (posedge clk or posedge rst)
begin
	if(rst)
	begin
		cnt <= 'h00;
		CNT_IO <= 'h00;
		PERIOD <= PERIOD_STATIC;
		PERIOD_IO <= 'h00;
		int <= 1'b0;
		int_rst_int_n <= 'h0;
	end
	else
	begin
		if(cnt >= PERIOD - 1)
		begin
			cnt <= 'h0;
			if(PERIOD)
				int <= 1'b1;
		end
		else if(PERIOD)
		begin
			cnt <= cnt + 1;
		end
		if(int_rst_int_n != int_rst_int)
		begin
			int_rst_int_n <= ~int_rst_int_n;
			int <= 1'b0;
		end
		if(wr_int)
		begin
			case(addr[2:0])
			`RTC_CNT_BYTE0: 
			begin
				cnt[(CNT_SIZE  >= 8 ? 7 : CNT_SIZE):0] <= bus_in;
				if(CNT_SIZE > 8)
				begin
					cnt[CNT_SIZE-1:8] <= CNT_IO;
				end
			end
			`RTC_CNT_BYTE1: 
			begin
				if(CNT_SIZE > 8)
				begin
					CNT_IO[(CNT_SIZE  >= 16 ? 7 : (CNT_SIZE-1-8)):0] <= bus_in;
				end
			end
			`RTC_CNT_BYTE2: 
			begin
				if(CNT_SIZE > 16)
				begin
					CNT_IO[(CNT_SIZE  >= 24 ? 15 : (CNT_SIZE-1-8)):8] <= bus_in;
				end
			end
			`RTC_CNT_BYTE3: 
			begin
				if(CNT_SIZE > 24)
				begin
					CNT_IO[CNT_SIZE-1-8:16] <= bus_in;
				end
			end
			`RTC_PERIOD_BYTE0: 
			begin
				PERIOD[(CNT_SIZE  >= 8 ? 7 : (CNT_SIZE-1)):0] <= bus_in;
				if(CNT_SIZE > 8)
				begin
					PERIOD[CNT_SIZE-1:8] <= PERIOD_IO;
				end
			end
			`RTC_PERIOD_BYTE1: 
			begin
				if(CNT_SIZE > 8)
				begin
					PERIOD_IO[(CNT_SIZE  >= 16 ? 7 : (CNT_SIZE-1-8)):0] <= bus_in;
				end
			end
			`RTC_PERIOD_BYTE2: 
			begin
				if(CNT_SIZE > 16)
				begin
					PERIOD_IO[(CNT_SIZE  >= 24 ? 15 : (CNT_SIZE-1-8)):8] <= bus_in;
				end
			end
			`RTC_PERIOD_BYTE3: 
			begin
				if(CNT_SIZE > 24)
				begin
					PERIOD_IO[(CNT_SIZE-1-8):16] <= bus_in;
				end
			end
			endcase
		end
		else if(rd_int)
		begin
			case(addr[2:0])
			`RTC_CNT_BYTE0: 
			begin
				//int <= 1'b0;
				if(CNT_SIZE > 8)
				begin
					CNT_IO <= cnt[CNT_SIZE-1:8];
				end
			end
			`RTC_PERIOD_BYTE0: 
			begin
				if(CNT_SIZE > 8)
				begin
					PERIOD_IO <= PERIOD[CNT_SIZE-1:8];
				end
			end
			endcase
		end
	end
	
end
 
always @ (*)
begin
	bus_out <= 8'h00;
	if(rd_int)
	begin
		case(addr[2:0])
		`RTC_CNT_BYTE0: 
		begin
			if(CNT_SIZE >= 8)
			begin
				bus_out <= cnt[7:0];
			end
			else
			begin
				bus_out <= {{8-CNT_SIZE{1'b0}}, cnt[CNT_SIZE-1-8:0]};
			end
		end
		`RTC_CNT_BYTE1: 
		begin
			if(CNT_SIZE > 8)
			begin
				if(CNT_SIZE >=16)
				begin
					bus_out <= CNT_IO[15:8];
				end
				else
				begin
					bus_out <= {{16-CNT_SIZE{1'b0}}, CNT_IO[CNT_SIZE-1-8:0]};
				end
			end
			//else
			//begin
			//	bus_out <= 0;
			//end
		end
		`RTC_CNT_BYTE2: 
		begin
			if(CNT_SIZE > 16)
			begin
				if(CNT_SIZE >=24)
				begin
					bus_out <= CNT_IO[23:16];
				end
				else
				begin
					bus_out <= {{24-CNT_SIZE{1'b0}}, CNT_IO[CNT_SIZE-1-8:8]};
				end
			end
			//else
			//begin
			//	bus_out <= 0;
			//end
		end
		`RTC_CNT_BYTE3: 
		begin
			if(CNT_SIZE > 24)
			begin
				bus_out <= {{32-CNT_SIZE{1'b0}}, CNT_IO[CNT_SIZE-1-8:16]};
			end
			//else
			//begin
			//	bus_out <= 0;
			//end
		end
		`RTC_PERIOD_BYTE0: 
		begin
			if(CNT_SIZE >= 8)
			begin
				bus_out <= PERIOD[7:0];
			end
			else
			begin
				bus_out <= {{8-CNT_SIZE{1'b0}}, PERIOD[CNT_SIZE-1:0]};
			end
		end
		`RTC_PERIOD_BYTE1: 
		begin
			if(CNT_SIZE > 8)
			begin 
				if(CNT_SIZE >=16)
				begin
					bus_out <= PERIOD_IO[15:8];
				end
				else
				begin
					bus_out <= {{16-CNT_SIZE{1'b0}}, PERIOD_IO[CNT_SIZE-1-8:0]};
				end
			end
			//else
			//begin
			//	bus_out <= 0;
			//end
		end
		`RTC_PERIOD_BYTE2: 
		begin
			if(CNT_SIZE > 16)
			begin
				if(CNT_SIZE >=24)
				begin
					bus_out <= PERIOD_IO[23:16];
				end
				else
				begin
					bus_out <= {{24-CNT_SIZE{1'b0}}, PERIOD_IO[CNT_SIZE-1-8:8]};
				end
			end
			//else
			//begin
			//	bus_out <= 0;
			//end
		end
		`RTC_PERIOD_BYTE3: 
		begin
			if(CNT_SIZE > 24)
			begin
				bus_out <= {{32-CNT_SIZE{1'b0}}, PERIOD_IO[CNT_SIZE-1-8:16]};
			end
			//else
			//begin
			//	bus_out <= 0;
			//end
		end
		endcase
	end
end

endmodule
