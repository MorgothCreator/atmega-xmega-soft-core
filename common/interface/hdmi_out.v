/*
 * This IP is the LCD to HDMI converter implementation.
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

module hdmi_out #(
	parameter PLATFORM = "XILINX_ARTIX_7",/* At this moment is supported only XILINX Artix7 platform. */
	parameter OUT_6BIT_PER_PIXEL = "TRUE"
	)(
	input rst,
	input clk,
	output hdmi_tx_cec,
	output hdmi_tx_clk_n,
	output hdmi_tx_clk_p,
	input hdmi_tx_hpd,
	output hdmi_tx_rscl,
	inout hdmi_tx_rsda,
	output [2:0]hdmi_tx_n,
	output [2:0]hdmi_tx_p,
	
	output lcd_clk_out,
	input lcd_h_synk,
	input lcd_v_synk,
	input [7:0]lcd_r,
	input [7:0]lcd_g,
	input [7:0]lcd_b,
	input lcd_de
	);
	
reg clk_5;/* This is a reference clock divided by 5 (is used to load the data in to OSERDES and pixel clock for LCD IP */


reg [7:0]lcd_r_int;
reg [7:0]lcd_g_int;
reg [7:0]lcd_b_int;

always @ (*)
begin
	lcd_r_int = lcd_r;
	lcd_g_int = lcd_g;
	lcd_b_int = lcd_b;
end

/* The serial data intermediate wire to go to differential output buffer for channel 0 */
wire hdmi_tx_p_0;
/* The 8 bit wire that represent the XOR/NXOR color symbol for channel 0 */
reg hdmi_tx_symbol_0_D0_;
reg hdmi_tx_symbol_0_D1_;
reg hdmi_tx_symbol_0_D2_;
reg hdmi_tx_symbol_0_D3_;
reg hdmi_tx_symbol_0_D4_;
reg hdmi_tx_symbol_0_D5_;
reg hdmi_tx_symbol_0_D6_;
reg hdmi_tx_symbol_0_D7_;
/* The 10 bit final symbol to feed the OSERDES device for channel 0 */
reg hdmi_tx_symbol_0_D0;
reg hdmi_tx_symbol_0_D1;
reg hdmi_tx_symbol_0_D2;
reg hdmi_tx_symbol_0_D3;
reg hdmi_tx_symbol_0_D4;
reg hdmi_tx_symbol_0_D5;
reg hdmi_tx_symbol_0_D6;
reg hdmi_tx_symbol_0_D7;
reg hdmi_tx_symbol_0_D8;
reg hdmi_tx_symbol_0_D9;

/* The serial data intermediate wire to go to differential output buffer for channel 1 */
wire hdmi_tx_p_1;
/* The 8 bit wire that represent the XOR/NXOR color symbol for channel 1 */
reg hdmi_tx_symbol_1_D0_;
reg hdmi_tx_symbol_1_D1_;
reg hdmi_tx_symbol_1_D2_;
reg hdmi_tx_symbol_1_D3_;
reg hdmi_tx_symbol_1_D4_;
reg hdmi_tx_symbol_1_D5_;
reg hdmi_tx_symbol_1_D6_;
reg hdmi_tx_symbol_1_D7_;
/* The 10 bit final symbol to feed the OSERDES device for channel 1 */
reg hdmi_tx_symbol_1_D0;
reg hdmi_tx_symbol_1_D1;
reg hdmi_tx_symbol_1_D2;
reg hdmi_tx_symbol_1_D3;
reg hdmi_tx_symbol_1_D4;
reg hdmi_tx_symbol_1_D5;
reg hdmi_tx_symbol_1_D6;
reg hdmi_tx_symbol_1_D7;
reg hdmi_tx_symbol_1_D8;
reg hdmi_tx_symbol_1_D9;

/* The serial data intermediate wire to go to differential output buffer for channel 2 */
wire hdmi_tx_p_2;
/* The 8 bit wire that represent the XOR/NXOR color symbol for channel 2 */
reg hdmi_tx_symbol_2_D0_;
reg hdmi_tx_symbol_2_D1_;
reg hdmi_tx_symbol_2_D2_;
reg hdmi_tx_symbol_2_D3_;
reg hdmi_tx_symbol_2_D4_;
reg hdmi_tx_symbol_2_D5_;
reg hdmi_tx_symbol_2_D6_;
reg hdmi_tx_symbol_2_D7_;
/* The 10 bit final symbol to feed the OSERDES device for channel 2 */
reg hdmi_tx_symbol_2_D0;
reg hdmi_tx_symbol_2_D1;
reg hdmi_tx_symbol_2_D2;
reg hdmi_tx_symbol_2_D3;
reg hdmi_tx_symbol_2_D4;
reg hdmi_tx_symbol_2_D5;
reg hdmi_tx_symbol_2_D6;
reg hdmi_tx_symbol_2_D7;
reg hdmi_tx_symbol_2_D8;
reg hdmi_tx_symbol_2_D9;
/* These three ounters are the symbol bias counter. */
reg [3:0]bias_cnt_0;
reg [3:0]bias_cnt_1;
reg [3:0]bias_cnt_2;

reg [4:0]dedicated_divider_clk_5;
assign lcd_clk_out = clk_5;
/* Calculate how many one bits are in each color data. */
wire [3:0]nr_of_ones_r = lcd_r_int[0] + lcd_r_int[1] + lcd_r_int[2] + lcd_r_int[3] + lcd_r_int[4] + lcd_r_int[5] + lcd_r_int[6] + lcd_r_int[7];
wire [3:0]nr_of_ones_g = lcd_g_int[0] + lcd_g_int[1] + lcd_g_int[2] + lcd_g_int[3] + lcd_g_int[4] + lcd_g_int[5] + lcd_g_int[6] + lcd_g_int[7];
wire [3:0]nr_of_ones_b = lcd_b_int[0] + lcd_b_int[1] + lcd_b_int[2] + lcd_b_int[3] + lcd_b_int[4] + lcd_b_int[5] + lcd_b_int[6] + lcd_b_int[7];
reg [3:0]nr_of_ones_in_last_symbol_0;
reg [3:0]nr_of_ones_in_last_symbol_1;
reg [3:0]nr_of_ones_in_last_symbol_2;
/* Here we calculate how many one bits including XOR/NXOR bit and excluding inverting bit on each chanel symbol.*/
wire [3:0]current_symbol_nr_of_ones_0 = hdmi_tx_symbol_0_D0_ + hdmi_tx_symbol_0_D1_ + hdmi_tx_symbol_0_D2_ + hdmi_tx_symbol_0_D3_ + hdmi_tx_symbol_0_D4_ + hdmi_tx_symbol_0_D5_ + hdmi_tx_symbol_0_D6_ + hdmi_tx_symbol_0_D7_ + hdmi_tx_symbol_0_D8;
wire [3:0]current_symbol_nr_of_ones_1 = hdmi_tx_symbol_1_D0_ + hdmi_tx_symbol_1_D1_ + hdmi_tx_symbol_1_D2_ + hdmi_tx_symbol_1_D3_ + hdmi_tx_symbol_1_D4_ + hdmi_tx_symbol_1_D5_ + hdmi_tx_symbol_1_D6_ + hdmi_tx_symbol_1_D7_ + hdmi_tx_symbol_1_D8;
wire [3:0]current_symbol_nr_of_ones_2 = hdmi_tx_symbol_2_D0_ + hdmi_tx_symbol_2_D1_ + hdmi_tx_symbol_2_D2_ + hdmi_tx_symbol_2_D3_ + hdmi_tx_symbol_2_D4_ + hdmi_tx_symbol_2_D5_ + hdmi_tx_symbol_2_D6_ + hdmi_tx_symbol_2_D7_ + hdmi_tx_symbol_2_D8;
/* Initialize mandatory registers in symulation mode. */
initial
begin
	clk_5 <= 'h0;
	dedicated_divider_clk_5 <= 5'b00000;
end
/* Divide the reference clock by 5, the positive edge of this clock is necessary for the OSERDES data load.  */
always @ (posedge clk)
begin
	if(dedicated_divider_clk_5 == 5'b00000)
		dedicated_divider_clk_5 <= 5'b00011;
	else
		dedicated_divider_clk_5 <= {dedicated_divider_clk_5[0], dedicated_divider_clk_5[4:1]};
end
always @ (posedge clk) clk_5 = dedicated_divider_clk_5[0];
/* Here we do XOR,NXOR of bits and inverse of the symbol to do the bias neutral signal.*/
always @ (posedge clk_5)
begin
	if(nr_of_ones_r < 4 || (nr_of_ones_r == 4 && lcd_r_int[0] == 1'b0))
	begin /* Do the XOR operation of red color bits. */
		hdmi_tx_symbol_0_D0_ = lcd_r_int[0];
		hdmi_tx_symbol_0_D1_ = lcd_r_int[1] ^ hdmi_tx_symbol_0_D0_;
		hdmi_tx_symbol_0_D2_ = lcd_r_int[2] ^ hdmi_tx_symbol_0_D1_;
		hdmi_tx_symbol_0_D3_ = lcd_r_int[3] ^ hdmi_tx_symbol_0_D2_;
		hdmi_tx_symbol_0_D4_ = lcd_r_int[4] ^ hdmi_tx_symbol_0_D3_;
		hdmi_tx_symbol_0_D5_ = lcd_r_int[5] ^ hdmi_tx_symbol_0_D4_;
		hdmi_tx_symbol_0_D6_ = lcd_r_int[6] ^ hdmi_tx_symbol_0_D5_;
		hdmi_tx_symbol_0_D7_ = lcd_r_int[7] ^ hdmi_tx_symbol_0_D6_;
		hdmi_tx_symbol_0_D8 = 1'b1; /* Set the eight bit to tell to receiver that this will be an XOR encoded red color symbol. */
	end
	else if(nr_of_ones_r > 4 || (nr_of_ones_r == 4 && lcd_r_int[0] == 1'b1))
	begin /* Do the NXOR operation of red color bits. */
		hdmi_tx_symbol_0_D0_ = lcd_r_int[0];
		hdmi_tx_symbol_0_D1_ = ~(lcd_r_int[1] ^ hdmi_tx_symbol_0_D0_);
		hdmi_tx_symbol_0_D2_ = ~(lcd_r_int[2] ^ hdmi_tx_symbol_0_D1_);
		hdmi_tx_symbol_0_D3_ = ~(lcd_r_int[3] ^ hdmi_tx_symbol_0_D2_);
		hdmi_tx_symbol_0_D4_ = ~(lcd_r_int[4] ^ hdmi_tx_symbol_0_D3_);
		hdmi_tx_symbol_0_D5_ = ~(lcd_r_int[5] ^ hdmi_tx_symbol_0_D4_);
		hdmi_tx_symbol_0_D6_ = ~(lcd_r_int[6] ^ hdmi_tx_symbol_0_D5_);
		hdmi_tx_symbol_0_D7_ = ~(lcd_r_int[7] ^ hdmi_tx_symbol_0_D6_);
		hdmi_tx_symbol_0_D8 = 1'b0; /* Clear the eight bit to tell to receiver that this will be an XOR encoded red color symbol. */
	end

	if(nr_of_ones_g < 4 || (nr_of_ones_g == 4 && lcd_g_int[0] == 1'b0))
	begin /* Do the XOR operation of green color bits. */
		hdmi_tx_symbol_1_D0_ = lcd_g_int[0];
		hdmi_tx_symbol_1_D1_ = lcd_g_int[1] ^ hdmi_tx_symbol_1_D0_;
		hdmi_tx_symbol_1_D2_ = lcd_g_int[2] ^ hdmi_tx_symbol_1_D1_;
		hdmi_tx_symbol_1_D3_ = lcd_g_int[3] ^ hdmi_tx_symbol_1_D2_;
		hdmi_tx_symbol_1_D4_ = lcd_g_int[4] ^ hdmi_tx_symbol_1_D3_;
		hdmi_tx_symbol_1_D5_ = lcd_g_int[5] ^ hdmi_tx_symbol_1_D4_;
		hdmi_tx_symbol_1_D6_ = lcd_g_int[6] ^ hdmi_tx_symbol_1_D5_;
		hdmi_tx_symbol_1_D7_ = lcd_g_int[7] ^ hdmi_tx_symbol_1_D6_;
		hdmi_tx_symbol_1_D8 = 1'b1; /* Set the eight bit to tell to receiver that this will be an XOR encoded green color symbol. */
	end
	else if(nr_of_ones_g > 4 || (nr_of_ones_g == 4 && lcd_g_int[0] == 1'b1))
	begin /* Do the NXOR operation of green color bits. */
		hdmi_tx_symbol_1_D0_ = lcd_g_int[0];
		hdmi_tx_symbol_1_D1_ = ~(lcd_g_int[1] ^ hdmi_tx_symbol_1_D0_);
		hdmi_tx_symbol_1_D2_ = ~(lcd_g_int[2] ^ hdmi_tx_symbol_1_D1_);
		hdmi_tx_symbol_1_D3_ = ~(lcd_g_int[3] ^ hdmi_tx_symbol_1_D2_);
		hdmi_tx_symbol_1_D4_ = ~(lcd_g_int[4] ^ hdmi_tx_symbol_1_D3_);
		hdmi_tx_symbol_1_D5_ = ~(lcd_g_int[5] ^ hdmi_tx_symbol_1_D4_);
		hdmi_tx_symbol_1_D6_ = ~(lcd_g_int[6] ^ hdmi_tx_symbol_1_D5_);
		hdmi_tx_symbol_1_D7_ = ~(lcd_g_int[7] ^ hdmi_tx_symbol_1_D6_);
		hdmi_tx_symbol_1_D8 = 1'b0; /* Clear the eight bit to tell to receiver that this will be an XOR encoded green color symbol. */
	end

	if(nr_of_ones_b < 4 || (nr_of_ones_b == 4 && lcd_b_int[0] == 1'b0))
	begin /* Do the XOR operation of blur color bits. */
		hdmi_tx_symbol_2_D0_ = lcd_b_int[0];
		hdmi_tx_symbol_2_D1_ = lcd_b_int[1] ^ hdmi_tx_symbol_2_D0_;
		hdmi_tx_symbol_2_D2_ = lcd_b_int[2] ^ hdmi_tx_symbol_2_D1_;
		hdmi_tx_symbol_2_D3_ = lcd_b_int[3] ^ hdmi_tx_symbol_2_D2_;
		hdmi_tx_symbol_2_D4_ = lcd_b_int[4] ^ hdmi_tx_symbol_2_D3_;
		hdmi_tx_symbol_2_D5_ = lcd_b_int[5] ^ hdmi_tx_symbol_2_D4_;
		hdmi_tx_symbol_2_D6_ = lcd_b_int[6] ^ hdmi_tx_symbol_2_D5_;
		hdmi_tx_symbol_2_D7_ = lcd_b_int[7] ^ hdmi_tx_symbol_2_D6_;
		hdmi_tx_symbol_2_D8 = 1'b1; /* Set the eight bit to tell to receiver that this will be an XOR encoded blue color symbol. */
	end
	else if(nr_of_ones_b > 4 || (nr_of_ones_b == 4 && lcd_b_int[0] == 1'b1))
	begin /* Do the NXOR operation of blur color bits. */
		hdmi_tx_symbol_2_D0_ = lcd_b_int[0];
		hdmi_tx_symbol_2_D1_ = ~(lcd_b_int[1] ^ hdmi_tx_symbol_2_D0_);
		hdmi_tx_symbol_2_D2_ = ~(lcd_b_int[2] ^ hdmi_tx_symbol_2_D1_);
		hdmi_tx_symbol_2_D3_ = ~(lcd_b_int[3] ^ hdmi_tx_symbol_2_D2_);
		hdmi_tx_symbol_2_D4_ = ~(lcd_b_int[4] ^ hdmi_tx_symbol_2_D3_);
		hdmi_tx_symbol_2_D5_ = ~(lcd_b_int[5] ^ hdmi_tx_symbol_2_D4_);
		hdmi_tx_symbol_2_D6_ = ~(lcd_b_int[6] ^ hdmi_tx_symbol_2_D5_);
		hdmi_tx_symbol_2_D7_ = ~(lcd_b_int[7] ^ hdmi_tx_symbol_2_D6_);
		hdmi_tx_symbol_2_D8 = 1'b0; /* Clear the eight bit to tell to receiver that this will be an XOR encoded blue color symbol. */
	end
	if(lcd_de)
	begin /* Here we encode 8 bit colors to 10 bit symbols taking in account the bias value of the last symbol and number of ones in current symbol. */
		if((bias_cnt_0[3:0] < 4 && current_symbol_nr_of_ones_0 >= 4) || (bias_cnt_0[3:0] >= 4 && current_symbol_nr_of_ones_0 <= 4))
		begin
			hdmi_tx_symbol_0_D9 = 1'b0;/* Send that this symbol is an inverted one on channel 0 setting the nineth bit in the symbol. */
			{hdmi_tx_symbol_0_D7, hdmi_tx_symbol_0_D6, hdmi_tx_symbol_0_D5, hdmi_tx_symbol_0_D4, hdmi_tx_symbol_0_D3, hdmi_tx_symbol_0_D2, hdmi_tx_symbol_0_D1, hdmi_tx_symbol_0_D0} = {hdmi_tx_symbol_0_D7_, hdmi_tx_symbol_0_D6_, hdmi_tx_symbol_0_D5_, hdmi_tx_symbol_0_D4_, hdmi_tx_symbol_0_D3_, hdmi_tx_symbol_0_D2_, hdmi_tx_symbol_0_D1_, hdmi_tx_symbol_0_D0_};
		end
		else
		begin
			hdmi_tx_symbol_0_D9 = 1'b1;/* Senjd that this symbol is an non inverted one on channel 0 clearing the nineth bit in the symbol. */
			{hdmi_tx_symbol_0_D7, hdmi_tx_symbol_0_D6, hdmi_tx_symbol_0_D5, hdmi_tx_symbol_0_D4, hdmi_tx_symbol_0_D3, hdmi_tx_symbol_0_D2, hdmi_tx_symbol_0_D1, hdmi_tx_symbol_0_D0} = ~{hdmi_tx_symbol_0_D7_, hdmi_tx_symbol_0_D6_, hdmi_tx_symbol_0_D5_, hdmi_tx_symbol_0_D4_, hdmi_tx_symbol_0_D3_, hdmi_tx_symbol_0_D2_, hdmi_tx_symbol_0_D1_, hdmi_tx_symbol_0_D0_};
		end
	
		if((bias_cnt_1[3:0] < 4 && current_symbol_nr_of_ones_1 > 4) || (bias_cnt_1[3:0] >= 4 && current_symbol_nr_of_ones_1 <= 4))
		begin
			hdmi_tx_symbol_1_D9 = 1'b0;/* Send that this symbol is an inverted one on channel 1 setting the nineth bit in the symbol. */
			{hdmi_tx_symbol_1_D7, hdmi_tx_symbol_1_D6, hdmi_tx_symbol_1_D5, hdmi_tx_symbol_1_D4, hdmi_tx_symbol_1_D3, hdmi_tx_symbol_1_D2, hdmi_tx_symbol_1_D1, hdmi_tx_symbol_1_D0} = {hdmi_tx_symbol_1_D7_, hdmi_tx_symbol_1_D6_, hdmi_tx_symbol_1_D5_, hdmi_tx_symbol_1_D4_, hdmi_tx_symbol_1_D3_, hdmi_tx_symbol_1_D2_, hdmi_tx_symbol_1_D1_, hdmi_tx_symbol_1_D0_};
		end
		else
		begin
			hdmi_tx_symbol_1_D9 = 1'b1;/* Senjd that this symbol is an non inverted one on channel 1 clearing the nineth bit in the symbol. */
			{hdmi_tx_symbol_1_D7, hdmi_tx_symbol_1_D6, hdmi_tx_symbol_1_D5, hdmi_tx_symbol_1_D4, hdmi_tx_symbol_1_D3, hdmi_tx_symbol_1_D2, hdmi_tx_symbol_1_D1, hdmi_tx_symbol_1_D0} = ~{hdmi_tx_symbol_1_D7_, hdmi_tx_symbol_1_D6_, hdmi_tx_symbol_1_D5_, hdmi_tx_symbol_1_D4_, hdmi_tx_symbol_1_D3_, hdmi_tx_symbol_1_D2_, hdmi_tx_symbol_1_D1_, hdmi_tx_symbol_1_D0_};
		end
	
		if((bias_cnt_2[3:0] < 4 && current_symbol_nr_of_ones_2 > 4) || (bias_cnt_2[3:0] >= 4 && current_symbol_nr_of_ones_2 <= 4))
		begin
			hdmi_tx_symbol_2_D9 = 1'b0;/* Send that this symbol is an inverted one on channel 2 setting the nineth bit in the symbol. */
			{hdmi_tx_symbol_2_D7, hdmi_tx_symbol_2_D6, hdmi_tx_symbol_2_D5, hdmi_tx_symbol_2_D4, hdmi_tx_symbol_2_D3, hdmi_tx_symbol_2_D2, hdmi_tx_symbol_2_D1, hdmi_tx_symbol_2_D0} = {hdmi_tx_symbol_2_D7_, hdmi_tx_symbol_2_D6_, hdmi_tx_symbol_2_D5_, hdmi_tx_symbol_2_D4_, hdmi_tx_symbol_2_D3_, hdmi_tx_symbol_2_D2_, hdmi_tx_symbol_2_D1_, hdmi_tx_symbol_2_D0_};
		end
		else
		begin
			hdmi_tx_symbol_2_D9 = 1'b1;/* Senjd that this symbol is an non inverted one on channel 2 clearing the nineth bit in the symbol. */
			{hdmi_tx_symbol_2_D7, hdmi_tx_symbol_2_D6, hdmi_tx_symbol_2_D5, hdmi_tx_symbol_2_D4, hdmi_tx_symbol_2_D3, hdmi_tx_symbol_2_D2, hdmi_tx_symbol_2_D1, hdmi_tx_symbol_2_D0} = ~{hdmi_tx_symbol_2_D7_, hdmi_tx_symbol_2_D6_, hdmi_tx_symbol_2_D5_, hdmi_tx_symbol_2_D4_, hdmi_tx_symbol_2_D3_, hdmi_tx_symbol_2_D2_, hdmi_tx_symbol_2_D1_, hdmi_tx_symbol_2_D0_};
		end
	end
	else
	begin /* Here we encode from 2 bit data (H & V synchronization signals to 10 bit symbols because we are outside of pixel data panel.*/
		case({lcd_v_synk, lcd_h_synk})/* Encode the H & V synchronization  signals in to respective 10 bit symbols and send the on channel 0. */
		2'b00: {hdmi_tx_symbol_0_D9, hdmi_tx_symbol_0_D8, hdmi_tx_symbol_0_D7, hdmi_tx_symbol_0_D6, hdmi_tx_symbol_0_D5, hdmi_tx_symbol_0_D4, hdmi_tx_symbol_0_D3, hdmi_tx_symbol_0_D2, hdmi_tx_symbol_0_D1, hdmi_tx_symbol_0_D0} = 10'b1101010100;
		2'b01: {hdmi_tx_symbol_0_D9, hdmi_tx_symbol_0_D8, hdmi_tx_symbol_0_D7, hdmi_tx_symbol_0_D6, hdmi_tx_symbol_0_D5, hdmi_tx_symbol_0_D4, hdmi_tx_symbol_0_D3, hdmi_tx_symbol_0_D2, hdmi_tx_symbol_0_D1, hdmi_tx_symbol_0_D0} = 10'b0010101011;
		2'b10: {hdmi_tx_symbol_0_D9, hdmi_tx_symbol_0_D8, hdmi_tx_symbol_0_D7, hdmi_tx_symbol_0_D6, hdmi_tx_symbol_0_D5, hdmi_tx_symbol_0_D4, hdmi_tx_symbol_0_D3, hdmi_tx_symbol_0_D2, hdmi_tx_symbol_0_D1, hdmi_tx_symbol_0_D0} = 10'b0101010100;
		2'b11: {hdmi_tx_symbol_0_D9, hdmi_tx_symbol_0_D8, hdmi_tx_symbol_0_D7, hdmi_tx_symbol_0_D6, hdmi_tx_symbol_0_D5, hdmi_tx_symbol_0_D4, hdmi_tx_symbol_0_D3, hdmi_tx_symbol_0_D2, hdmi_tx_symbol_0_D1, hdmi_tx_symbol_0_D0} = 10'b1010101011;
		endcase
		/* Here we send dummy neutral symbols ( The logic control value 2'b00 ), because in this case we do not send control values, we send this symbols on channel 1 & 2.. */
		{hdmi_tx_symbol_1_D9, hdmi_tx_symbol_1_D8, hdmi_tx_symbol_1_D7, hdmi_tx_symbol_1_D6, hdmi_tx_symbol_1_D5, hdmi_tx_symbol_1_D4, hdmi_tx_symbol_1_D3, hdmi_tx_symbol_1_D2, hdmi_tx_symbol_1_D1, hdmi_tx_symbol_1_D0} = 10'b1101010100;
		{hdmi_tx_symbol_2_D9, hdmi_tx_symbol_2_D8, hdmi_tx_symbol_2_D7, hdmi_tx_symbol_2_D6, hdmi_tx_symbol_2_D5, hdmi_tx_symbol_2_D4, hdmi_tx_symbol_2_D3, hdmi_tx_symbol_2_D2, hdmi_tx_symbol_2_D1, hdmi_tx_symbol_2_D0} = 10'b1101010100;
	end
end
/* Here we count the bias. */
always @ (posedge clk_5 or posedge rst)
begin
	if(rst)
	begin
		bias_cnt_0 <= 'd4;
		bias_cnt_1 <= 'd4;
		bias_cnt_2 <= 'd4;
		nr_of_ones_in_last_symbol_0 = 'h4;
		nr_of_ones_in_last_symbol_1 = 'h4;
		nr_of_ones_in_last_symbol_2 = 'h4;
	end
	else
	begin
		if(lcd_de)
		begin /* Here we count the bias only when transmiting the color symbols. */
			nr_of_ones_in_last_symbol_0 = hdmi_tx_symbol_0_D0 + hdmi_tx_symbol_0_D1 + hdmi_tx_symbol_0_D2 + hdmi_tx_symbol_0_D3 + hdmi_tx_symbol_0_D4 + hdmi_tx_symbol_0_D5 + hdmi_tx_symbol_0_D6 + hdmi_tx_symbol_0_D7 + hdmi_tx_symbol_0_D8 + hdmi_tx_symbol_0_D9;
			nr_of_ones_in_last_symbol_1 = hdmi_tx_symbol_1_D0 + hdmi_tx_symbol_1_D1 + hdmi_tx_symbol_1_D2 + hdmi_tx_symbol_1_D3 + hdmi_tx_symbol_1_D4 + hdmi_tx_symbol_1_D5 + hdmi_tx_symbol_1_D6 + hdmi_tx_symbol_1_D7 + hdmi_tx_symbol_1_D8 + hdmi_tx_symbol_1_D9;
			nr_of_ones_in_last_symbol_2 = hdmi_tx_symbol_2_D0 + hdmi_tx_symbol_2_D1 + hdmi_tx_symbol_2_D2 + hdmi_tx_symbol_2_D3 + hdmi_tx_symbol_2_D4 + hdmi_tx_symbol_2_D5 + hdmi_tx_symbol_2_D6 + hdmi_tx_symbol_2_D7 + hdmi_tx_symbol_2_D8 + hdmi_tx_symbol_2_D9;
			if(nr_of_ones_in_last_symbol_0 < 4)
				bias_cnt_0 <= bias_cnt_0 - nr_of_ones_in_last_symbol_0;
			else if(nr_of_ones_in_last_symbol_0 > 4)
				bias_cnt_0 <= bias_cnt_0 + (nr_of_ones_in_last_symbol_0 - 4);
			if(nr_of_ones_in_last_symbol_1 < 4)
				bias_cnt_1 <= bias_cnt_1 - nr_of_ones_in_last_symbol_1;
			else if(nr_of_ones_in_last_symbol_1 > 4)
				bias_cnt_1 <= bias_cnt_1 + (nr_of_ones_in_last_symbol_1 - 4);
			if(nr_of_ones_in_last_symbol_2 < 4)
				bias_cnt_2 <= bias_cnt_2 - nr_of_ones_in_last_symbol_2;
			else if(nr_of_ones_in_last_symbol_2 > 4)
				bias_cnt_2 <= bias_cnt_2 + (nr_of_ones_in_last_symbol_2 - 4);
		end
		else
		begin /* We do not count the bias if no pixel data is transmited, we reset it to a neutral value, because all control symbols has neutral biases. */
			bias_cnt_0 <= 'd4;
			bias_cnt_1 <= 'd4;
			bias_cnt_2 <= 'd4;
		end
	end
end
/* This section is platform dependent, contain only the four channel diferential output buffers and output 10 bit SERDES in DDR mode */
generate
if(PLATFORM == "XILINX_ARTIX_7")
begin
/* Clock differential buffer */
OBUFDS #(
	.IOSTANDARD("TMDS_33"), // Specify the output I/O standard
	.SLEW("SLOW")           // Specify the output slew rate
	) OBUFDS_clk_inst (
	.O(hdmi_tx_clk_p),     // Diff_p output (connect directly to top-level port)
	.OB(hdmi_tx_clk_n),   // Diff_n output (connect directly to top-level port)
	.I(clk_5)      // Buffer input
	);

/* Channel 0 differential buffer */
OBUFDS #(
	.IOSTANDARD("TMDS_33"), // Specify the output I/O standard
	.SLEW("SLOW")           // Specify the output slew rate
	) OBUFDS_0_inst (
	.O(hdmi_tx_p[0]),     // Diff_p output (connect directly to top-level port)
	.OB(hdmi_tx_n[0]),   // Diff_n output (connect directly to top-level port)
	.I(hdmi_tx_p_0)      // Buffer input
	);

/* Channel 1 differential buffer */
OBUFDS #(
	.IOSTANDARD("TMDS_33"), // Specify the output I/O standard
	.SLEW("SLOW")           // Specify the output slew rate
	) OBUFDS_1_inst (
	.O(hdmi_tx_p[1]),     // Diff_p output (connect directly to top-level port)
	.OB(hdmi_tx_n[1]),   // Diff_n output (connect directly to top-level port)
	.I(hdmi_tx_p_1)      // Buffer input
	);

/* Channel 2 differential buffer */
OBUFDS #(
	.IOSTANDARD("TMDS_33"), // Specify the output I/O standard
	.SLEW("SLOW")           // Specify the output slew rate
	) OBUFDS_2_inst (
	.O(hdmi_tx_p[2]),     // Diff_p output (connect directly to top-level port)
	.OB(hdmi_tx_n[2]),   // Diff_n output (connect directly to top-level port)
	.I(hdmi_tx_p_2)      // Buffer input
	);

wire OSERDES_SHIFT1_CH0;
wire OSERDES_SHIFT2_CH0;
wire OSERDES_SHIFT1_CH1;
wire OSERDES_SHIFT2_CH1;
wire OSERDES_SHIFT1_CH2;
wire OSERDES_SHIFT2_CH2;


/* Channel 0 OSERDES (two phases of 10 bits each) */
OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),   // DDR, SDR
	.DATA_RATE_TQ("SDR"),   // DDR, BUF, SDR
	.DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
	.INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
	.INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
	.SERDES_MODE("MASTER"), // MASTER, SLAVE
	.SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
	.SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
	.TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
	.TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
	.TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
	) OSERDESE2_0_LOW_inst (
	.OQ(hdmi_tx_p_0),               // 1-bit output: Data path output
	.CLK(clk),             // 1-bit input: High speed clock
	.CLKDIV(clk_5),       // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D1(hdmi_tx_symbol_0_D0),
	.D2(hdmi_tx_symbol_0_D1),
	.D3(hdmi_tx_symbol_0_D2),
	.D4(hdmi_tx_symbol_0_D3),
	.D5(hdmi_tx_symbol_0_D4),
	.D6(hdmi_tx_symbol_0_D5),
	.D7(hdmi_tx_symbol_0_D6),
	.D8(hdmi_tx_symbol_0_D7),
	.OCE(1'b1),             // 1-bit input: Output data clock enable
	.RST(rst),             // 1-bit input: Reset
	.SHIFTIN1(OSERDES_SHIFT1_CH0),
	.SHIFTIN2(OSERDES_SHIFT2_CH0)
	);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),   // DDR, SDR
	.DATA_RATE_TQ("SDR"),   // DDR, BUF, SDR
	.DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
	.INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
	.INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
	.SERDES_MODE("SLAVE"), // MASTER, SLAVE
	.SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
	.SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
	.TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
	.TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
	.TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
	) OSERDESE2_0_HIGH_inst (
	.SHIFTOUT1(OSERDES_SHIFT1_CH0),
	.SHIFTOUT2(OSERDES_SHIFT2_CH0),
	.CLK(clk),             // 1-bit input: High speed clock
	.CLKDIV(clk_5),       // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D3(hdmi_tx_symbol_0_D8),
	.D4(hdmi_tx_symbol_0_D9),
	.OCE(1'b1),             // 1-bit input: Output data clock enable
	.RST(rst)             // 1-bit input: Reset
	);

/* Channel 1 OSERDESE2 (two phases of 10 bits each) */
OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),   // DDR, SDR
	.DATA_RATE_TQ("SDR"),   // DDR, BUF, SDR
	.DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
	.INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
	.INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
	.SERDES_MODE("MASTER"), // MASTER, SLAVE
	.SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
	.SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
	.TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
	.TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
	.TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
	) OSERDESE2_1_LOW_inst (
	.OQ(hdmi_tx_p_1),               // 1-bit output: Data path output
	.CLK(clk),             // 1-bit input: High speed clock
	.CLKDIV(clk_5),       // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D1(hdmi_tx_symbol_1_D0),
	.D2(hdmi_tx_symbol_1_D1),
	.D3(hdmi_tx_symbol_1_D2),
	.D4(hdmi_tx_symbol_1_D3),
	.D5(hdmi_tx_symbol_1_D4),
	.D6(hdmi_tx_symbol_1_D5),
	.D7(hdmi_tx_symbol_1_D6),
	.D8(hdmi_tx_symbol_1_D7),
	.OCE(1'b1),             // 1-bit input: Output data clock enable
	.RST(rst),             // 1-bit input: Reset
	.SHIFTIN1(OSERDES_SHIFT1_CH1),
	.SHIFTIN2(OSERDES_SHIFT2_CH1)
	);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),   // DDR, SDR
	.DATA_RATE_TQ("SDR"),   // DDR, BUF, SDR
	.DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
	.INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
	.INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
	.SERDES_MODE("SLAVE"), // MASTER, SLAVE
	.SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
	.SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
	.TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
	.TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
	.TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
	) OSERDESE2_1_HIGH_inst (
	.SHIFTOUT1(OSERDES_SHIFT1_CH1),
	.SHIFTOUT2(OSERDES_SHIFT2_CH1),
	.CLK(clk),             // 1-bit input: High speed clock
	.CLKDIV(clk_5),       // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D3(hdmi_tx_symbol_1_D8),
	.D4(hdmi_tx_symbol_1_D9),
	.OCE(1'b1),             // 1-bit input: Output data clock enable
	.RST(rst)             // 1-bit input: Reset
	);

/* Channel 2 OSERDESE2 (two phases of 10 bits each) */
OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),   // DDR, SDR
	.DATA_RATE_TQ("SDR"),   // DDR, BUF, SDR
	.DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
	.INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
	.INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
	.SERDES_MODE("MASTER"), // MASTER, SLAVE
	.SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
	.SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
	.TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
	.TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
	.TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
	) OSERDESE2_2_LOW_inst (
	.OQ(hdmi_tx_p_2),               // 1-bit output: Data path output
	.CLK(clk),             // 1-bit input: High speed clock
	.CLKDIV(clk_5),       // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D1(hdmi_tx_symbol_2_D0),
	.D2(hdmi_tx_symbol_2_D1),
	.D3(hdmi_tx_symbol_2_D2),
	.D4(hdmi_tx_symbol_2_D3),
	.D5(hdmi_tx_symbol_2_D4),
	.D6(hdmi_tx_symbol_2_D5),
	.D7(hdmi_tx_symbol_2_D6),
	.D8(hdmi_tx_symbol_2_D7),
	.OCE(1'b1),             // 1-bit input: Output data clock enable
	.RST(rst),             // 1-bit input: Reset
	.SHIFTIN1(OSERDES_SHIFT1_CH2),
	.SHIFTIN2(OSERDES_SHIFT2_CH2)
	);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),   // DDR, SDR
	.DATA_RATE_TQ("SDR"),   // DDR, BUF, SDR
	.DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
	.INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
	.INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
	.SERDES_MODE("SLAVE"), // MASTER, SLAVE
	.SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
	.SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
	.TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
	.TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
	.TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
	) OSERDESE2_2_HIGH_inst (
	.SHIFTOUT1(OSERDES_SHIFT1_CH2),
	.SHIFTOUT2(OSERDES_SHIFT2_CH2),
	.CLK(clk),             // 1-bit input: High speed clock
	.CLKDIV(clk_5),       // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D3(hdmi_tx_symbol_2_D8),
	.D4(hdmi_tx_symbol_2_D9),
	.OCE(1'b1),             // 1-bit input: Output data clock enable
	.RST(rst)             // 1-bit input: Reset
	);

end
endgenerate


endmodule
