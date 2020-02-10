/*
 * This IP is the SPI implementation.
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

module spi_s #(
	parameter DINAMIC_BAUDRATE = "TRUE",
	parameter BAUDRATE_DIVIDER = 3,
	parameter ADDRESS = 0,
	parameter BUS_ADDR_DATA_LEN = 16
    )(
	input rst,
	input clk,
	input [BUS_ADDR_DATA_LEN-1:0]addr,
	input wr,
	input rd,
	input [7:0]bus_in,
	output reg[7:0]bus_out,
	output req_bus,
	output int,

	output sck,/* SPI 'sck' signal (output) */
	output mosi,/* SPI 'mosi' signal (output) */
	input miso,/* SPI 'miso' signal (input) */
	output reg ss/* SPI 'ss' signal (if send buffer is maintained full the ss signal will not go high between between transmit chars)(output) */
    );

//reg [7:0]CTRL;
//reg [7:0]BAUD;

assign req_bus = addr >= ADDRESS && addr < (ADDRESS + 8);
wire rd_int = req_bus && rd;
wire wr_int = req_bus && wr;

reg [7:0]baud_cnt;

wire buffempty;

reg [7:0]CTRL;
reg [7:0]INTCTRL;
reg [7:0]STATUS;

	
localparam WORD_LEN = 8;
localparam PRESCALLER_SIZE = 8;

reg _mosi;

reg charreceivedp;
reg charreceivedn;

reg inbufffullp = 1'b0;
reg inbufffulln = 1'b0;

reg [WORD_LEN - 1:0]input_buffer;
reg [WORD_LEN - 1:0]output_buffer;

assign buffempty = ~(inbufffullp ^ inbufffulln);
reg [2:0]prescallerbuff;

always @ (posedge clk or posedge rst)
begin
	if(rst)
	begin
		inbufffullp <= 1'b0;
		prescallerbuff <= 3'b000;
		CTRL <= 0;
		INTCTRL <= 0;
		input_buffer <= 0;
	end
	else
	begin
		if(wr_int)
		begin
			case(addr[2:0])
			`SPI_CTRL: CTRL <= bus_in;
			`SPI_INTCTRL: INTCTRL <= bus_in;
			`SPI_DATA: 
			begin
				if(inbufffullp == inbufffulln && buffempty && CTRL[`SPI_ENABLE_bp])
				begin
					inbufffullp <= ~inbufffullp;
					prescallerbuff <= {CTRL[`SPI_CLK2X_bp], CTRL[`SPI_PRESCALER_gp + 1:`SPI_PRESCALER_gp]};
					input_buffer <= bus_in;
				end
			end
			endcase
		end
	end
end

always @ (posedge clk or posedge rst)
begin
	if(rst)
	begin
		STATUS <= 8'h00;
		charreceivedn <= 1'b0;
	end
	else if(rd_int)
	begin
		case(addr[2:0])
		`SPI_DATA: STATUS[`SPI_IF_bp] <= 1'b0;
		endcase
	end
	else if(charreceivedp != charreceivedn)
	begin
		STATUS[`SPI_IF_bp] <= 1'b1;
		charreceivedn <= ~charreceivedn;
	end	

end

always @ (*)
begin
	bus_out <= 8'b00;
	if(rd_int)
	begin
		case(addr[2:0])
		`SPI_CTRL: bus_out <= CTRL;
		`SPI_INTCTRL: bus_out <= INTCTRL;
		`SPI_STATUS: bus_out <= STATUS;
		`SPI_DATA: bus_out <= output_buffer;
		endcase
	end
end

assign int = INTCTRL[`SPI_INTLVL_gp + 1: `SPI_INTLVL_gp] ? STATUS[`SPI_IF_bp] : 1'b0;

/***********************************************/
/************ !Asynchronus send ****************/
/***********************************************/
localparam state_idle = 1'b0;
localparam state_busy = 1'b1;
reg state;


reg [PRESCALLER_SIZE - 1:0]prescaller_cnt;
reg [WORD_LEN - 1:0]shift_reg_out;
reg [WORD_LEN - 1:0]shift_reg_in;
reg [4:0]sckint;
//reg sckintn;
reg [2:0]prescallerint;
reg [7:0]prescdemux;


always @ (*)
begin
	case(prescallerint)
	3'b000: prescdemux <= 3;
	3'b001: prescdemux <= 15;
	3'b010: prescdemux <= 63;
	3'b011: prescdemux <= 127;
	3'b100: prescdemux <= 1;
	3'b101: prescdemux <= 7;
	3'b110: prescdemux <= 31;
	3'b111: prescdemux <= 63;
	endcase
end

reg lsbfirstint;
reg [1:0]modeint;


always	@	(posedge clk or	posedge rst)
begin
	if(rst)
	begin
		baud_cnt = 'h00;
        inbufffulln <= 1'b0;
		ss <= 1'b1;
		state <= state_idle;
		prescaller_cnt <= {PRESCALLER_SIZE{1'b0}};
		prescallerint <= {PRESCALLER_SIZE{3'b0}};
		shift_reg_out <= {WORD_LEN{1'b0}};
		shift_reg_in <= {WORD_LEN{1'b0}};
		sckint <=  {5{1'b0}};
		_mosi <= 1'b1;
		output_buffer <= {WORD_LEN{1'b0}};
		charreceivedp <= 1'b0;
		lsbfirstint <= 1'b0;
		modeint <= 2'b00;
	end
	else
	begin
		if(CTRL[`SPI_ENABLE_bp])
		begin
			if(DINAMIC_BAUDRATE == "TRUE" ? baud_cnt == prescdemux : baud_cnt == {BAUDRATE_DIVIDER})
			begin
			baud_cnt <= 'h00;
				case(state)
				state_idle:
					begin
						if(inbufffullp != inbufffulln)
						begin
							inbufffulln <= ~inbufffulln;
							ss <= 1'b0;
							prescaller_cnt <= {PRESCALLER_SIZE{1'b0}};
							prescallerint <= prescallerbuff;
							lsbfirstint <= CTRL[`SPI_DORD_bp];
							modeint <= CTRL[`SPI_MODE_gp + 1:`SPI_MODE_gp];
							shift_reg_out <= input_buffer;
							state <= state_busy;
							if(!CTRL[`SPI_MODE_gp])
							begin
								if(!CTRL[`SPI_DORD_bp])
									_mosi <= input_buffer[WORD_LEN - 1];
								else
									_mosi <= input_buffer[0];
							end
						end
					end
					state_busy:
					begin
						if(prescaller_cnt != prescdemux)
						begin
							prescaller_cnt <= prescaller_cnt + 1;
						end
						else
						begin
							prescaller_cnt <= {PRESCALLER_SIZE{1'b0}};
							sckint <= sckint + 1;
							if(sckint[0] == modeint[0])
							begin
								if(!lsbfirstint)
								begin
									shift_reg_in <= {miso, shift_reg_in[7:1]};
									shift_reg_out <= {shift_reg_out[6:0], 1'b1};
								end
								else
								begin
									shift_reg_in <= {shift_reg_in[6:0], miso};
									shift_reg_out <= {1'b1, shift_reg_out[7:1]};
								end
							end
							else
							begin
								if(sckint[4:1] == WORD_LEN - 1)
								begin
									sckint <= {5{1'b0}};
									if(inbufffullp == inbufffulln)
									begin
										ss <= 1'b1;
									end
									output_buffer <= shift_reg_in;
									if(charreceivedp == charreceivedn)
									begin
										charreceivedp <= ~charreceivedp;
									end
									state <= state_idle;
								end
								else
								begin
								if(!lsbfirstint)
									_mosi <= shift_reg_out[WORD_LEN - 1];
								else
									_mosi <= shift_reg_out[0];
								end
							end
						end
					end
				endcase
			end
			else
			begin
				baud_cnt <= baud_cnt + 1;
			end
		end
	end
end

assign sck = (modeint[1])? ~sckint : sckint;
assign mosi = (ss) ? 1'b1:_mosi;

endmodule
