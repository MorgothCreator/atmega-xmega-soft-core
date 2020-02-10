/*
 * This IP is the paralel IO implementation.
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

module pio_s #(
	parameter DINAMIC_IN_OUT_CONFIG = "FALSE",
	parameter IN_OUT_MASK_CONFIG = 8'h00,
	parameter INVERT_IN_OUT = 8'h00,
	parameter USE_INTERRUPTS = "FALSE",
	parameter DINAMIC_INTERRUPT_CONFIG = "FALSE",
	parameter INTERRUPT_MASK_CONFIG = 8'h00,
	parameter INTERRUPT_UP_DN_EDGE_DETECT = 8'h00,
	parameter INTERRUPT_BOTH_EDGES_DETECT_MASK = 8'h00,
	parameter BUS_KEPPER_EN_MASK = 0,
	parameter BUS_PULL_UP_EN_MASK = 0,
	parameter BUS_PULL_DN_EN_MASK = 0,
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
	input int_rst,
	inout [7:0]io
	);


reg [7:0]IO_DIR;
reg [7:0]IO_OUT;
reg [7:0]INTMASK;
reg [7:0]INTFLAGS;
reg [7:0]PINCTRL[0:7];


reg [7:0]INT_DETECT_POSEDGE;
reg [7:0]INT_DETECT_POSEDGE_n;
reg [7:0]INT_DETECT_NEGEDGE;
reg [7:0]INT_DETECT_NEGEDGE_n;

assign req_bus = addr >= ADDRESS && addr < (ADDRESS + 32);
wire rd_int = req_bus && rd;
wire wr_int = req_bus && wr;

wire [7:0]io_int;
assign io_int[7] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[7][`PORT_INVEN_bp] ^ io[7]) : (INVERT_IN_OUT[7] ? ~ io[7] : io[7]);
assign io_int[6] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[6][`PORT_INVEN_bp] ^ io[6]) : (INVERT_IN_OUT[6] ? ~ io[6] : io[6]);
assign io_int[5] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[5][`PORT_INVEN_bp] ^ io[5]) : (INVERT_IN_OUT[5] ? ~ io[5] : io[5]);
assign io_int[4] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[4][`PORT_INVEN_bp] ^ io[4]) : (INVERT_IN_OUT[4] ? ~ io[4] : io[4]);
assign io_int[3] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[3][`PORT_INVEN_bp] ^ io[3]) : (INVERT_IN_OUT[3] ? ~ io[3] : io[3]);
assign io_int[2] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[2][`PORT_INVEN_bp] ^ io[2]) : (INVERT_IN_OUT[2] ? ~ io[2] : io[2]);
assign io_int[1] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[1][`PORT_INVEN_bp] ^ io[1]) : (INVERT_IN_OUT[1] ? ~ io[1] : io[1]);
assign io_int[0] = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (PINCTRL[0][`PORT_INVEN_bp] ^ io[0]) : (INVERT_IN_OUT[0] ? ~ io[0] : io[0]);

integer cnt_detect;

always @ (posedge clk or posedge rst)
begin
	if(rst)
	begin
		IO_DIR <= 'h00;
		IO_OUT <= 'h00;
		INTMASK <= 'h00;
		INTFLAGS <= 'h00;
		INT_DETECT_POSEDGE_n <= 'h00;
		INT_DETECT_NEGEDGE_n <= 'h00;
	end
	else
	begin
		if(wr_int)
		begin
			case(addr[4:0])
			`PORT_DIR: 
			begin
				if(DINAMIC_IN_OUT_CONFIG == "TRUE")
					IO_DIR <= bus_in;
			end
			`PORT_DIRSET: 
			begin
				if(DINAMIC_IN_OUT_CONFIG == "TRUE")
					IO_DIR <= IO_DIR | bus_in;
			end
			`PORT_DIRCLR: 
			begin
				if(DINAMIC_IN_OUT_CONFIG == "TRUE")
					IO_DIR <= IO_DIR & (~bus_in);
			end
			`PORT_DIRTGL: 
			begin
				if(DINAMIC_IN_OUT_CONFIG == "TRUE")
					IO_DIR <= IO_DIR ^ (~bus_in);
			end
			`PORT_OUT: IO_OUT <= bus_in;
			`PORT_OUTSET: IO_OUT <= IO_OUT | bus_in;
			`PORT_OUTCLR: IO_OUT <= IO_OUT & (~bus_in);
			`PORT_OUTTGL: IO_OUT <= IO_OUT ^ (~bus_in);
			`PORT_INT0MASK: INTMASK <= bus_in;
			`PORT_INTFLAGS: INTFLAGS <= INTFLAGS & (~bus_in);
			endcase
			if(addr[4])
				PINCTRL[addr[2:0]] <= bus_in;
		end
		else
		begin
			if(USE_INTERRUPTS == "TRUE")
			begin
				for (cnt_detect = 0; cnt_detect < 8; cnt_detect = cnt_detect + 1)
				begin
					if(INT_DETECT_POSEDGE_n[cnt_detect] != INT_DETECT_POSEDGE[cnt_detect])
					begin
						INTFLAGS[cnt_detect] <= 1'b1;
						INT_DETECT_POSEDGE_n[cnt_detect] <= ~INT_DETECT_POSEDGE_n[cnt_detect];
					end
					else if(INT_DETECT_NEGEDGE_n[cnt_detect] != INT_DETECT_NEGEDGE[cnt_detect])
					begin
						INTFLAGS[cnt_detect] <= 1'b1;
						INT_DETECT_NEGEDGE_n[cnt_detect] <= ~INT_DETECT_NEGEDGE_n[cnt_detect];
					end
				end
			end
		end
	end
end

always @ (*)
begin
	bus_out <= 8'h00;
	if(rd_int)
	begin
		case(addr[4:0])
		`PORT_DIR,
		`PORT_DIRSET: bus_out <= DINAMIC_IN_OUT_CONFIG == "TRUE" ? IO_DIR : 'hzz;
		`PORT_DIRCLR: bus_out <= DINAMIC_IN_OUT_CONFIG == "TRUE" ? ~IO_DIR : 'hzz;
		`PORT_OUT,
		`PORT_OUTSET: bus_out <= DINAMIC_IN_OUT_CONFIG == "TRUE" ? IO_OUT : 'hzz;
		`PORT_OUTCLR: bus_out <= DINAMIC_IN_OUT_CONFIG == "TRUE" ? ~IO_OUT : 'hzz;
		`PORT_IN: bus_out <= io_int;
		`PORT_INT0MASK: bus_out <= USE_INTERRUPTS == "TRUE" ? (DINAMIC_INTERRUPT_CONFIG == "TRUE" ? INTMASK : INTERRUPT_MASK_CONFIG) : 'hzz;
		`PORT_INTFLAGS: bus_out <= USE_INTERRUPTS == "TRUE" ? INTFLAGS : 'hzz;
		endcase
		if(addr[4])
			bus_out <= USE_INTERRUPTS == "TRUE" || DINAMIC_IN_OUT_CONFIG == "TRUE" ? PINCTRL[addr[2:0]] : 'hzz;
	end
end
									
wire out_0 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[0] ? (PINCTRL[0][`PORT_INVEN_bp] ^ IO_OUT[0]) : 1'bz) : (IN_OUT_MASK_CONFIG[0] ? (INVERT_IN_OUT[0] ? ~IO_OUT[0] : IO_OUT[0]) : 1'bz);
wire out_1 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[1] ? (PINCTRL[1][`PORT_INVEN_bp] ^ IO_OUT[1]) : 1'bz) : (IN_OUT_MASK_CONFIG[1] ? (INVERT_IN_OUT[1] ? ~IO_OUT[1] : IO_OUT[1]) : 1'bz);
wire out_2 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[2] ? (PINCTRL[2][`PORT_INVEN_bp] ^ IO_OUT[2]) : 1'bz) : (IN_OUT_MASK_CONFIG[2] ? (INVERT_IN_OUT[2] ? ~IO_OUT[2] : IO_OUT[2]) : 1'bz);
wire out_3 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[3] ? (PINCTRL[3][`PORT_INVEN_bp] ^ IO_OUT[3]) : 1'bz) : (IN_OUT_MASK_CONFIG[3] ? (INVERT_IN_OUT[3] ? ~IO_OUT[3] : IO_OUT[3]) : 1'bz);
wire out_4 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[4] ? (PINCTRL[4][`PORT_INVEN_bp] ^ IO_OUT[4]) : 1'bz) : (IN_OUT_MASK_CONFIG[4] ? (INVERT_IN_OUT[4] ? ~IO_OUT[4] : IO_OUT[4]) : 1'bz);
wire out_5 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[5] ? (PINCTRL[5][`PORT_INVEN_bp] ^ IO_OUT[5]) : 1'bz) : (IN_OUT_MASK_CONFIG[5] ? (INVERT_IN_OUT[5] ? ~IO_OUT[5] : IO_OUT[5]) : 1'bz);
wire out_6 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[6] ? (PINCTRL[6][`PORT_INVEN_bp] ^ IO_OUT[6]) : 1'bz) : (IN_OUT_MASK_CONFIG[6] ? (INVERT_IN_OUT[6] ? ~IO_OUT[6] : IO_OUT[6]) : 1'bz);
wire out_7 = DINAMIC_IN_OUT_CONFIG == "TRUE" ? (IO_DIR[7] ? (PINCTRL[7][`PORT_INVEN_bp] ^ IO_OUT[7]) : 1'bz) : (IN_OUT_MASK_CONFIG[7] ? (INVERT_IN_OUT[7] ? ~IO_OUT[7] : IO_OUT[7]) : 1'bz);

assign io = {out_7, out_6, out_5, out_4, out_3, out_2, out_1, out_0};

assign int = USE_INTERRUPTS == "TRUE" ? |INTFLAGS : 'h00;

wire _int_mode_up_edge0 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[0] ? (PINCTRL[0][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[0][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[0] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[0] : INTERRUPT_UP_DN_EDGE_DETECT[0]);
wire _int_mode_up_edge1 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[1] ? (PINCTRL[1][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[1][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[1] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[1] : INTERRUPT_UP_DN_EDGE_DETECT[1]);
wire _int_mode_up_edge2 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[2] ? (PINCTRL[2][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[2][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[2] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[2] : INTERRUPT_UP_DN_EDGE_DETECT[2]);
wire _int_mode_up_edge3 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[3] ? (PINCTRL[3][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[3][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[3] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[3] : INTERRUPT_UP_DN_EDGE_DETECT[3]);
wire _int_mode_up_edge4 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[4] ? (PINCTRL[4][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[4][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[4] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[4] : INTERRUPT_UP_DN_EDGE_DETECT[4]);
wire _int_mode_up_edge5 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[5] ? (PINCTRL[5][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[5][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[5] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[5] : INTERRUPT_UP_DN_EDGE_DETECT[5]);
wire _int_mode_up_edge6 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[6] ? (PINCTRL[6][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[6][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[6] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[6] : INTERRUPT_UP_DN_EDGE_DETECT[6]);
wire _int_mode_up_edge7 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[7] ? (PINCTRL[7][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[7][3:0] == `PORT_ISC_RISING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[7] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[7] : INTERRUPT_UP_DN_EDGE_DETECT[7]);
wire [7:0]int_mode_up_edge = {_int_mode_up_edge7, _int_mode_up_edge6, _int_mode_up_edge5, _int_mode_up_edge4, _int_mode_up_edge3, _int_mode_up_edge2, _int_mode_up_edge1, _int_mode_up_edge0};

wire _int_mode_dn_edge0 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[0] ? (PINCTRL[0][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[0][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[0] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[0] : ~INTERRUPT_UP_DN_EDGE_DETECT[0]);
wire _int_mode_dn_edge1 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[1] ? (PINCTRL[1][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[1][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[1] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[1] : ~INTERRUPT_UP_DN_EDGE_DETECT[1]);
wire _int_mode_dn_edge2 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[2] ? (PINCTRL[2][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[2][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[2] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[2] : ~INTERRUPT_UP_DN_EDGE_DETECT[2]);
wire _int_mode_dn_edge3 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[3] ? (PINCTRL[3][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[3][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[3] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[3] : ~INTERRUPT_UP_DN_EDGE_DETECT[3]);
wire _int_mode_dn_edge4 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[4] ? (PINCTRL[4][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[4][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[4] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[4] : ~INTERRUPT_UP_DN_EDGE_DETECT[4]);
wire _int_mode_dn_edge5 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[5] ? (PINCTRL[5][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[5][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[5] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[5] : ~INTERRUPT_UP_DN_EDGE_DETECT[5]);
wire _int_mode_dn_edge6 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[6] ? (PINCTRL[6][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[6][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[6] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[6] : ~INTERRUPT_UP_DN_EDGE_DETECT[6]);
wire _int_mode_dn_edge7 = DINAMIC_INTERRUPT_CONFIG == "TRUE" ? (INTMASK[7] ? (PINCTRL[7][3:0] == `PORT_ISC_BOTHEDGES_gc) || (PINCTRL[7][3:0] == `PORT_ISC_FALLING_gc) : 1'b0) : (INTERRUPT_MASK_CONFIG[7] ? INTERRUPT_BOTH_EDGES_DETECT_MASK[7] : ~INTERRUPT_UP_DN_EDGE_DETECT[7]);
wire [7:0]int_mode_dn_edge = {_int_mode_dn_edge7, _int_mode_dn_edge6, _int_mode_dn_edge5, _int_mode_dn_edge4, _int_mode_dn_edge3, _int_mode_dn_edge2, _int_mode_dn_edge1, _int_mode_dn_edge0};

genvar cnt;
generate

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:POSEDGE
	always @ (posedge io_int[cnt] or posedge rst)
	begin
		if(USE_INTERRUPTS == "TRUE")
		begin
			if(rst)
				INT_DETECT_POSEDGE[cnt] <= 'h00;
			else if(INT_DETECT_POSEDGE_n[cnt] == INT_DETECT_POSEDGE[cnt] && int_mode_up_edge)
				INT_DETECT_POSEDGE[cnt] <= ~INT_DETECT_POSEDGE[cnt];
		end
	end
end

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:NEGEDGE
	always @ (negedge io_int[cnt] or posedge rst)
	begin
		if(USE_INTERRUPTS == "TRUE")
		begin
			if(rst)
				INT_DETECT_NEGEDGE[cnt] <= 'h00;
			else if(INT_DETECT_NEGEDGE_n[cnt] == INT_DETECT_NEGEDGE[cnt] && int_mode_dn_edge)
				INT_DETECT_NEGEDGE[cnt] <= ~INT_DETECT_NEGEDGE[cnt];
		end
	end
end

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:KEPPERS
	if (BUS_KEPPER_EN_MASK[cnt])
	begin
		KEEPER KEEPER_inst (
			.O(io[cnt])     // Keeper output (connect directly to top-level port)
		);
	end
end

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:PULLUPS
	if (BUS_PULL_UP_EN_MASK[cnt])
	begin
		PULLUP PULLUP_inst (
			.O(io[cnt])     // PullUp output (connect directly to top-level port)
		);
	end
end

for (cnt = 0; cnt < 8; cnt = cnt + 1)
begin:PULLDOWNS
	if (BUS_PULL_DN_EN_MASK[cnt])
	begin
		PULLDOWN PULLDOWN_inst (
			.O(io[cnt])     // PullDown output (connect directly to top-level port)
		);
	end
end

endgenerate

endmodule
