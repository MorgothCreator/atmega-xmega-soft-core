/*
 * This IP is the UART implementation.
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

module uart_s #(
	parameter BAUDRATE_COUNTER_LENGTH = 12,
	parameter DINAMIC_BAUDRATE = "TRUE",
	parameter BAUDRATE_DIVIDER = 19200,
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
    output int_rx_rcv,
    output int_tx_compl,
    output int_tx_buff_empty,
    inout int_rst,
    inout rtx_clk,
    output reg tx,
    input rx
    );

localparam [6:0]MAX_WORD_LEN = 9;

localparam	state_idle	=	1'b0;
localparam	state_busy	=	1'b1;

reg [7:0]DATA_in;
reg [7:0]DATA_out;
reg [7:0]STATUS;
reg [7:0]CTRLA;
reg [7:0]CTRLB;
reg [7:0]CTRLC;
reg [7:0]BAUDCTRLA;
reg [7:0]BAUDCTRLB;
reg [7:0]BAUDCTRLB_tmp_read;
reg [7:0]BAUDCTRLB_tmp_write;

assign req_bus = addr >= ADDRESS && addr < (ADDRESS + 16);
wire rd_int = req_bus && rd;
wire wr_int = req_bus && wr;

reg [BAUDRATE_COUNTER_LENGTH == 0 ? 0 : BAUDRATE_COUNTER_LENGTH - 1:0]baud_cnt;

reg receiveoverrunp;
reg receiveoverrunn;
wire receiveoverrunpn;

reg [2:0]rxbitcntstate;

reg	charreceivedp;
reg	charreceivedn;

reg	state_rx;
reg	state_tx;
reg	[(MAX_WORD_LEN - 1) + 4:0]shift_reg_in;
reg	[(MAX_WORD_LEN - 1) + 4:0]shift_reg_out;
//reg	[MAX_WORD_LEN - 1:0]temp_output_buffer;
reg	[7:0]sckint_rx;
//reg	[3:0]bitcount_rx;
reg [3:0]total_word_len_rx;

wire _chk_int;
wire chk_int;
reg [(MAX_WORD_LEN - 1) + 4:0]parity_mask;
wire [(MAX_WORD_LEN - 1) + 4:0]valid_data;
wire parity_bit;
reg [3:0]wordlen;

reg	inbufffullp;
reg	inbufffulln;

reg last_state_rxp;
reg last_state_rxn;
wire rx_start_detected;

reg	[3:0]sckint_tx;
reg	[3:0]bitcount_tx;
reg [3:0]total_word_len_tx;

wire buffempty = ~(inbufffullp ^ inbufffulln);
reg [BAUDRATE_COUNTER_LENGTH - 1:0]prescallerbuff;

reg int_tx_compl_int;
reg int_tx_buff_empty_int;
assign int_tx_compl = CTRLB[`USART_TXEN_bp] ? int_tx_compl_int : 1'b0;
assign int_tx_buff_empty = CTRLB[`USART_TXEN_bp] ? int_tx_buff_empty_int : 1'b0;
reg int_rx_rcv_int;
assign int_rx_rcv = CTRLB[`USART_RXEN_bp] ? int_rx_rcv_int : 1'b0;

wire [BAUDRATE_COUNTER_LENGTH - 1:0]static_baudrate = {BAUDCTRLB, BAUDCTRLA};

always @ (posedge rd_int or posedge rst)
begin
	if(rst)
	begin
		charreceivedn	<=	1'b0;
		receiveoverrunp <= 1'b0;
	end
	else if(rd_int)
	begin
		case(addr[3:0])
		`USART_DATA: 
		begin
			if(charreceivedp !=	charreceivedn)
				charreceivedn <= ~charreceivedn;
			if(receiveoverrunn != receiveoverrunp)
				receiveoverrunp <= ~receiveoverrunp;
		end
		endcase
	end
end

always @ (*)
begin
	bus_out <= 8'b00;
	if(rst)
	begin
		BAUDCTRLB_tmp_read <= 'h0;
	end
	else if(rd_int)
	begin
		case(addr[3:0])
		`USART_DATA: bus_out <= DATA_out;
		`USART_STATUS: bus_out <= STATUS;
		`USART_CTRLA: bus_out <= CTRLA;
		`USART_CTRLB: bus_out <= CTRLB;
		`USART_CTRLC: bus_out <= CTRLC;
		`USART_BAUDCTRLA: 
		begin
			if(DINAMIC_BAUDRATE == "TRUE")
			begin
				bus_out <= BAUDCTRLA;
				BAUDCTRLB_tmp_read <= BAUDCTRLB;
			end
			else
			begin
				bus_out <= static_baudrate[7:0];
			end
		end
		`USART_BAUDCTRLB: 
		begin
			if(DINAMIC_BAUDRATE == "TRUE")
				bus_out <= BAUDCTRLB_tmp_read;
			else
				bus_out <= {4'h0, static_baudrate[BAUDRATE_COUNTER_LENGTH - 1:8]};
		end
		//default: bus_out <= 8'bz;
		endcase
	end
	//else
	//begin
	//	bus_out <= 8'bz;
	//end
end


always @ (*)
begin
	case(CTRLC[`USART_CHSIZE_gp + 2:`USART_CHSIZE_gp])
		3'h00: wordlen <= 12'd5;
		3'h01: wordlen <= 12'd6;
		3'h02: wordlen <= 12'd7;
		3'h03: wordlen <= 12'd8;
		3'h07: wordlen <= 12'd9;
		default: wordlen <= 12'd8;
	endcase
end

always @ (*)
begin
	case(wordlen)
		4'h05: parity_mask <= 12'b000000111110;
		4'h06: parity_mask <= 12'b000001111110;
		4'h07: parity_mask <= 12'b000011111110;
		4'h09: parity_mask <= 12'b001111111110;
		default: parity_mask <= 12'b000111111110;
	endcase
end
						
assign valid_data = shift_reg_in & parity_mask;
assign _chk_int = ^valid_data;
assign chk_int = (CTRLC[`USART_CMODE_gp + 1:`USART_CMODE_gp] == 2'b10) ? ~_chk_int:_chk_int;
assign parity_bit = (shift_reg_in & (1 << wordlen + 1)) ? 1:0;

always @ (negedge rx or	posedge rst)
begin
	if(rst)
		last_state_rxn <= 0;
	else
	begin
		if(last_state_rxn == last_state_rxp)
		begin
			last_state_rxn <= ~last_state_rxp;
		end
	end
end

assign rx_start_detected = (last_state_rxn ^ last_state_rxp);

always @ (posedge clk or posedge rst)
begin
	if(rst)
	begin
		baud_cnt = 'h00;
        charreceivedn <= 1'b0;
		inbufffullp <= 1'b0;
		inbufffulln <= 1'b0;
		DATA_in <=	'h0;
		STATUS <= 'h0;
		CTRLA <= 'h0;
		CTRLB <= 'h0;
		CTRLC <= `USART_CHSIZE_8BIT_gc;
		BAUDCTRLA <= 'h0;
		BAUDCTRLB <= 'h0;
		BAUDCTRLB_tmp_write <= 'h0;
		last_state_rxp <= 'h0;
		state_rx <=	state_idle;
		state_tx <=	state_idle;
		shift_reg_in <=	'h0;
		sckint_rx <= 'h0;
		charreceivedp <= 'h0;
		receiveoverrunn <= 'h0;
		rxbitcntstate <= 'h0;
		total_word_len_rx <= 'h0;
		int_rx_rcv_int <= 'h0;
		int_tx_compl_int <= 'h0;
		int_tx_buff_empty_int <= 'h0;
		tx <= 1'b1;
	end
	else
	begin
		STATUS[`USART_DREIF_bp] <= buffempty;
/*
		 * Read from IO logic
		 */
		if(wr_int)
		begin
			case(addr[3:0])
			`USART_STATUS: STATUS <= STATUS ^ bus_in;
			`USART_CTRLA: CTRLA <= bus_in;
			`USART_CTRLB: CTRLB <= bus_in;
			`USART_CTRLC: CTRLC <= bus_in;
			`USART_BAUDCTRLA: 
			begin
				if(DINAMIC_BAUDRATE == "TRUE")
				begin
					BAUDCTRLA <= bus_in;
					BAUDCTRLB <= BAUDCTRLB_tmp_write;
				end
			end
			`USART_BAUDCTRLB: 
			begin
				if(DINAMIC_BAUDRATE == "TRUE")
				begin
					BAUDCTRLB_tmp_write <= bus_in;
				end
			end
			`USART_DATA: 
			begin
				if(inbufffullp == inbufffulln && buffempty && CTRLB[`USART_TXEN_bp])
				begin
					inbufffullp <= ~inbufffullp;
					prescallerbuff <= {BAUDCTRLB[BAUDRATE_COUNTER_LENGTH - 1 - 8:0], BAUDCTRLA};
					DATA_in <= bus_in;
					int_tx_compl_int <= 1'b0;
					int_tx_buff_empty_int <= 'h0;
				end
			end
			endcase
		end
		if(rd_int)
		begin
			case(addr[3:0])
			`USART_DATA: int_rx_rcv_int <= 1'b0;
			endcase
		end
		if(DINAMIC_BAUDRATE == "TRUE" ? baud_cnt == prescallerbuff : baud_cnt == {BAUDRATE_DIVIDER})
		begin
			baud_cnt <= 'h00;
			if(CTRLB[`USART_RXEN_bp])
			begin
/*
 * Rx logic
 */
				if(state_rx == state_idle)
				begin
					// Wait for a transition from hi to low that indicate a start condition.
					if(rx_start_detected)
					begin
						shift_reg_in <= 0;
						sckint_rx <= 0;
						rxbitcntstate <= 7;
						// Calculate the total number of bits to receive including end.
						total_word_len_rx <= CTRLC[`USART_CMODE_gp + 1:`USART_CMODE_gp] ? 1 : 0 + 1 + CTRLC[`USART_SBMODE_bp] + wordlen;
						state_rx <= state_busy;
					end
				end
				else
				begin
					case(sckint_rx[3:0])
						7,8,9: 
						begin
							rxbitcntstate <= rxbitcntstate + (rx ? 3'd7 : 3'd1);
							sckint_rx <= sckint_rx + 1;
						end
						10:
						begin 
							if(sckint_rx[7:4] == total_word_len_rx)// If is stop bit check-it and out the received data.
							begin
								// Verify stop bit to be valid, else report a frame error.
								STATUS[`USART_FERR_bp] <= ~rxbitcntstate[2];
								// Verify the parity bit
								if(CTRLC[`USART_CMODE_gp + 1:`USART_CMODE_gp])
									STATUS[`USART_PERR_bp] <= parity_bit ^ chk_int;
								else
									STATUS[`USART_PERR_bp] <= 'h0;
								// Put data from shift register to output data register.
								{STATUS[`USART_RXB8_bp], DATA_out} <= valid_data[9:1];
								// Check if the previous received data has been read from output register, if not report a overrun situation..
								if(charreceivedn == charreceivedp)
									charreceivedp <= ~charreceivedp;
								else
								begin
									if(receiveoverrunn == receiveoverrunp)
										receiveoverrunn <= ~receiveoverrunn;
								end
								if(CTRLA[`USART_RXCINTLVL_gp + 1 : `USART_RXCINTLVL_gp])
								begin
									int_rx_rcv_int <= 1'b1;
								end
								state_rx <= state_idle;
								sckint_rx <= 0;
								last_state_rxp <= last_state_rxn; 
							end
							else
							begin
								shift_reg_in[sckint_rx[7:4]] <= rxbitcntstate[2];
								sckint_rx <= sckint_rx + 1;
							end
						end
						15:
						begin
							rxbitcntstate <= 7;
							sckint_rx <= sckint_rx + 1;
						end
						default:
						begin
							sckint_rx <= sckint_rx + 1;
						end
					endcase
				end
			end
			else
			begin
				int_rx_rcv_int <= 'h0;
			end
/*
 * Tx logic
 */
			if(CTRLB[`USART_TXEN_bp])
			begin
				case(state_tx)
					state_idle:
					begin
						if(inbufffullp != inbufffulln)
						begin
							inbufffulln <= ~inbufffulln;
							sckint_tx <= 5'h01;
							int_tx_compl_int <= 1'b0;
							if(CTRLA[`USART_DREINTLVL_gc + 1 : `USART_DREINTLVL_gc])
							begin
								int_tx_buff_empty_int <= 'h1;
							end
							case({CTRLC[`USART_PMODE_gp + 1 : `USART_PMODE_gp], CTRLC[`USART_SBMODE_bp], wordlen})
								{2'b00, 4'h05}: shift_reg_out	<=	{1'b1, DATA_in[4:0], 1'h0};
								{2'b00, 4'h06}: shift_reg_out	<=	{1'b1, DATA_in[5:0], 1'h0};
								{2'b00, 4'h07}: shift_reg_out	<=	{1'b1, DATA_in[6:0], 1'h0};
								{2'b00, 4'h08}: shift_reg_out	<=	{1'b1, DATA_in, 1'h0};
								{2'b00, 4'h09}: shift_reg_out	<=	{1'b1, CTRLB[`USART_TXB8_bp], DATA_in, 1'h0};
								{2'b01, 4'h05}: shift_reg_out	<=	{2'b11, DATA_in[4:0], 1'h0};
								{2'b01, 4'h06}: shift_reg_out	<=	{2'b11, DATA_in[5:0], 1'h0};
								{2'b01, 4'h07}: shift_reg_out	<=	{2'b11, DATA_in[6:0], 1'h0};
								{2'b01, 4'h08}: shift_reg_out	<=	{2'b11, DATA_in, 1'h0};
								{2'b01, 4'h09}: shift_reg_out	<=	{2'b11, CTRLB[`USART_TXB8_bp], DATA_in, 1'h0};
								{2'b10, 4'h05}: shift_reg_out	<=	{1'b1, chk_int, DATA_in[4:0], 1'h0};
								{2'b10, 4'h06}: shift_reg_out	<=	{1'b1, chk_int, DATA_in[5:0], 1'h0};
								{2'b10, 4'h07}: shift_reg_out	<=	{1'b1, chk_int, DATA_in[6:0], 1'h0};
								{2'b10, 4'h08}: shift_reg_out	<=	{1'b1, chk_int, DATA_in, 1'h0};
								{2'b10, 4'h09}: shift_reg_out	<=	{1'b1, chk_int, CTRLB[`USART_TXB8_bp], DATA_in, 1'h0};
								{2'b11, 4'h05}:shift_reg_out	<=	{2'b11, chk_int, DATA_in[4:0], 1'h0};
								{2'b11, 4'h06}:shift_reg_out	<=	{2'b11, chk_int, DATA_in[5:0], 1'h0};
								{2'b11, 4'h07}:shift_reg_out	<=	{2'b11, chk_int, DATA_in[6:0], 1'h0};
								{2'b11, 4'h08}:shift_reg_out	<=	{2'b11, chk_int, DATA_in, 1'h0};
								{2'b11, 4'h09}:shift_reg_out	<=	{2'b11, chk_int, CTRLB[`USART_TXB8_bp], DATA_in, 1'h0};
								default: shift_reg_out	<=	{1'b1, DATA_in[7:0], 1'h0};
							endcase
							bitcount_tx <= 4'b0000;
							total_word_len_tx <= CTRLC[`USART_PMODE_gp + 1:`USART_PMODE_gp] ? 1 : 0 + 1 + CTRLC[`USART_SBMODE_bp] + wordlen + 1;
							state_tx <=	state_busy;
							/*Put start, first bit from shift_reg_out*/
							tx <= 1'b0;
						end
					end
					state_busy:
					begin
						case(sckint_tx)
						4'h0D:
						begin
							sckint_tx <= sckint_tx + 1;
							bitcount_tx <= bitcount_tx + 'b0001;
						end
						4'h0E:
						begin
							if(bitcount_tx == total_word_len_tx)
							begin
								state_tx <= state_idle;
								if(CTRLA[`USART_TXCINTLVL_gp + 1 : `USART_TXCINTLVL_gp])
								begin
									int_tx_compl_int <= 1'b1;
								end
							end
							sckint_tx <= sckint_tx + 1;
						end
						4'h0F:
						begin
							sckint_tx	<= sckint_tx + 1;
							tx <= shift_reg_out[bitcount_tx];
						end
						default:
						begin
							sckint_tx <= sckint_tx + 1;
						end
						endcase
					end
				endcase
			end
			else
			begin
				int_tx_compl_int <= 'h0;
				int_tx_buff_empty_int <= 'h0;
			end
		end
		else
		begin
			baud_cnt <= baud_cnt + 1;
		end
	end
end


endmodule
