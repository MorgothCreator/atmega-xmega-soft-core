/*
 * This IP is the TWI implementation.
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

module twi_s #(
	parameter DINAMIC_BAUDRATE = "TRUE",
	parameter BAUDRATE_DIVIDER = 255,
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
	output int_tx_cmpl,
	output int_rx_cmpl,
	input int_tx_rst,
	input int_rx_rst,
	
	inout scl,
	inout sda
    );

reg [7:0]CTRLA;
reg [7:0]CTRLB;
reg [7:0]CTRLC;
reg [7:0]STATUS;
reg [7:0]BAUD;
reg [7:0]DATA;

assign req_bus = addr >= ADDRESS && addr < (ADDRESS + 16);
wire rd_int = req_bus && rd;
wire wr_int = req_bus && wr;

reg [7:0]baud_cnt;
reg [1:0]cmd;
reg tx_mode;
reg start_sent;
reg rcv_ack;
reg send_ack;
reg send_ack_st2;
reg [1:0]stage;
reg [2:0]bit_count;
reg scl_int;
reg sda_int;
reg send_ack_int;

localparam [2:0]CMD_NOP = {1'b1, 2'b00};
localparam [2:0]CMD_RESTART = {1'b0, 2'b01};
localparam [2:0]CMD_RECEIVE = {1'b0, 2'b10};
localparam [2:0]CMD_STOP = {1'b0, 2'b11};

always @ (*)
begin
	bus_out <= 8'h00;
	if(rd_int)
	begin
		case(addr[3:0])
		`TWI_MASTER_CTRLA: bus_out <= CTRLA;
		`TWI_MASTER_CTRLB: bus_out <= CTRLB;
		`TWI_MASTER_CTRLC: bus_out <= CTRLC;
		`TWI_MASTER_STATUS: bus_out <= STATUS;
		`TWI_MASTER_BAUD: bus_out <= BAUD;
		`TWI_MASTER_DATA: bus_out <= DATA;
		endcase
	end
end

always @ (posedge clk or posedge rst)
begin
	if(rst)
	begin
		CTRLA <= 'h0;
		CTRLB <= 'h0;
		CTRLC <= 'h0;
		STATUS <= 'h0;
		BAUD <= 'h0;
		DATA <= 'h0;
		baud_cnt <= 'h00;
		cmd <= 'h00;
		tx_mode <= 1'b0;
		start_sent <= 1'b0;
		scl_int <= 1'b1;
		sda_int <= 1'b1;
		rcv_ack <= 1'b0;
		send_ack <= 1'b0;
		send_ack_st2 <= 1'b0;
		stage <= 'h00;
		send_ack_int <= 1'b1;
	end
	else
	begin
		if(DINAMIC_BAUDRATE == "TRUE" ? baud_cnt == BAUD : baud_cnt == BAUDRATE_DIVIDER)
		begin
			baud_cnt <= 'h00;
			if(CTRLA[`TWI_MASTER_ENABLE_bp])
			begin
				case({tx_mode, cmd})
				CMD_NOP:
				begin
					if(~start_sent)
					begin/* Send the start sequence */
						stage <= stage + 1;
						case(stage)
						'h0:
						begin
							scl_int <= 1'b1;
							sda_int <= 1'b0;
						end
						'h1:
						begin
							scl_int <= 1'b0;
							bit_count <= 'hF;
							start_sent <= 1'b1;
							stage <= 'h0;
						end
						endcase
					end
					else
					begin/* Send bits */
						stage <= stage + 1;
						case(stage)
						'h0:
						begin
							case(rcv_ack)
							1'b0:
							begin
								sda_int <= DATA[bit_count];
							end
							1'b1:
								sda_int <= 1'b1;
							endcase
						end
						'h1:
						begin
							scl_int <= 1'b1;
						end
						'h2:
						begin
							if(rcv_ack)
								STATUS[`TWI_MASTER_RXACK_bp] <= sda;
						end
						'h3:
						begin
							stage <= 'h0;
							scl_int <= 1'b0;
							case(rcv_ack)
							1'b0:
							begin
								if(~|bit_count)
									rcv_ack <= 1'b1;
								bit_count <= bit_count - 1;
							end
							1'b1:
							begin
								tx_mode <= 1'b0;
								STATUS[`TWI_MASTER_WIF_bp] <= 1'b1;
								rcv_ack <= 1'b0;
							end
							endcase
						end
						endcase
					end
				end
				CMD_RESTART:
				begin/* Send restart */
					stage <= stage + 1;
					case(stage)
					'h0:
					begin
						sda_int <= 1'b1;
					end
					'h1:
					begin
						scl_int <= 1'b1;
					end
					'h2:
					begin
						sda_int <= 1'b0;
					end
					'h3:
					begin
						scl_int <= 1'b0;
						bit_count <= 'hF;
						start_sent <= 1'b1;
						stage <= 'h0;
						cmd <= 'h0;
						CTRLC[`TWI_MASTER_CMD_gp + 1:`TWI_MASTER_CMD_gp] <= 'h0;
					end
					endcase
				end
				CMD_RECEIVE:
				begin/* Receive bits */
					stage <= stage + 1;
					case(stage)
					'h0:
					begin
						if(send_ack && ~send_ack_st2)
							sda_int <= send_ack_int;
						else if(send_ack_st2)
						begin
							STATUS[`TWI_MASTER_RIF_bp] <= 1'b1;
							cmd <= 'h0;
							CTRLC[`TWI_MASTER_CMD_gp + 1:`TWI_MASTER_CMD_gp] <= 'h0;
							sda_int <= 1'b1;
						end
					end
					'h1:
					begin
						scl_int <= 1'b1;
					end
					'h2:
					begin
						if(~send_ack)
							DATA[bit_count] <= sda;
					end
					'h3:
					begin
						scl_int <= 1'b0;
						stage <= 'h0;
						case(send_ack)
						1'b0:
						begin
							if(~|bit_count)
								send_ack <= 1'b1;
							bit_count <= bit_count - 1;
						end
						1'b1: send_ack_st2 <= 1'b1;
						endcase
					end
					endcase
				end
				CMD_STOP:
				begin/* Send stop */
					stage <= stage + 1;
					case(stage)
					'h0: sda_int <= 1'b0;
					'h1: scl_int <= 1'b1;
					'h2:
					begin
						sda_int <= 1'b1;
						start_sent <= 1'b0;
						stage <= 'h0;
						cmd <= 'h0;
						CTRLC[`TWI_MASTER_CMD_gp + 1:`TWI_MASTER_CMD_gp] <= 'h0;
					end
					endcase
				end
			endcase
			end
		end
		else
		begin
			baud_cnt <= baud_cnt + 1;
		end
		if(CTRLA[`TWI_MASTER_ENABLE_bp])
		begin
			if(CTRLC[`TWI_MASTER_CMD_gp + 1:`TWI_MASTER_CMD_gp] && ~|cmd && ~tx_mode)
			begin
				cmd <= CTRLC[`TWI_MASTER_CMD_gp + 1:`TWI_MASTER_CMD_gp];
				stage <= 'h0;
				send_ack <= 1'b0;
				send_ack_st2 <= 1'b0;
				send_ack_int <= CTRLC[`TWI_SLAVE_ACKACT_bp];
			end
		end
		if(wr_int)
		begin
			case(addr[3:0])
			`TWI_MASTER_CTRLA: CTRLA <= bus_in;
			`TWI_MASTER_CTRLB: CTRLB <= bus_in;
			`TWI_MASTER_CTRLC: CTRLC <= bus_in;
			`TWI_MASTER_STATUS: STATUS <= STATUS ^ bus_in;
			`TWI_MASTER_BAUD: BAUD <= bus_in;
			//`TWI_MASTER_ADDR: ADDR <= bus_in;
			`TWI_MASTER_DATA: 
			begin
				if(~|CTRLC[`TWI_MASTER_CMD_gp + 1:`TWI_MASTER_CMD_gp])
				begin
					DATA <= bus_in;
					tx_mode <= 1'b1;
					STATUS[`TWI_MASTER_WIF_bp] <= 1'b0;
				end
			end
			endcase
		end
		if(rd_int)
		begin
			case(addr[3:0])
			`TWI_MASTER_DATA: 
			begin
				STATUS[`TWI_MASTER_RIF_bp] <= 1'b0;
			end
			endcase
		end
	end
end

PULLUP PULLUP_scl_inst (
	.O(scl)  // 1-bit output: Pullup output (connect directly to top-level port)
);
PULLUP PULLUP_sda_inst (
	.O(sda)  // 1-bit output: Pullup output (connect directly to top-level port)
);


assign scl = scl_int ? 1'bz : scl_int;
assign sda = sda_int ? 1'bz : sda_int;

endmodule
