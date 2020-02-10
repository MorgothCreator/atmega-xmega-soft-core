/*
 * This IP is the LCD implementation.
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

//Dependencies: fifo.v

module lcd #(
	parameter MASTER = "TRUE",
	parameter DEBUG = "PATERN_RASTER",//"PATERN_RASTER"
	parameter DISPLAY_CFG = "",
	
	parameter ADDRESS = 0,
	parameter BUS_VRAM_ADDR_LEN = 24,
	parameter BUS_VRAM_DATA_LEN = 8,
	parameter BUS_ADDR_DATA_LEN = 16,
	
	parameter DINAMIC_CONFIG = "FALSE",
	parameter VRAM_BASE_ADDRESS_CONF = 0,
	parameter H_RES_CONF = 800,
	parameter H_BACK_PORCH_CONF = 46,
	parameter H_FRONT_PORCH_CONF = 210,
	parameter H_PULSE_WIDTH_CONF = 2,
	parameter V_RES_CONF = 480,
	parameter V_BACK_PORCH_CONF = 23,
	parameter V_FRONT_PORCH_CONF = 22,
	parameter V_PULSE_WIDTH_CONF = 2,
	parameter PIXEL_SIZE_CONF = 16,
	parameter HSYNK_INVERTED_CONF = 1'b1,
	parameter VSYNK_INVERTED_CONF = 1'b1,
	parameter DATA_ENABLE_INVERTED_CONF = 1'b0,
	
	parameter COLOR_INVERTED = 0,

	parameter DEDICATED_VRAM_SIZE = 0,
	
	parameter FIFO_DEPTH = 256
)(
	input rst,
	input ctrl_clk,
    input [BUS_ADDR_DATA_LEN-1:0]ctrl_addr,
	input ctrl_wr,
	input ctrl_rd,
	input [7:0]ctrl_data_in,
	output reg [7:0]ctrl_data_out,

	inout [BUS_VRAM_ADDR_LEN-1:0]vmem_addr,
	input [BUS_VRAM_DATA_LEN-1:0]vmem_in,
	output [BUS_VRAM_DATA_LEN-1:0]vmem_out,
	input vmem_rd,
	input vmem_wr,
	
	input lcd_clk,
	output lcd_h_synk,
	output lcd_v_synk,
	output [7:0]lcd_r,
	output [7:0]lcd_g,
	output [7:0]lcd_b,
	output lcd_de,
	
	output [12:0]h_cnt_out,
	output [12:0]v_cnt_out,
	input [31:0]color_data_in

);

wire cs_int = ctrl_addr >= ADDRESS && ctrl_addr < (ADDRESS + 16);
wire rd_int = cs_int && ctrl_rd;
wire wr_int = cs_int && ctrl_wr;
/* These are the dinamic configuration registers, when the IP is configured in dinamic configuration mode. */
reg EN;
reg HSYNK_INVERTED;
reg VSYNK_INVERTED;
reg DATA_ENABLE_INVERTED;
reg [15:0]H_RES;
reg [7:0]H_PULSE_WIDTH;
reg [7:0]H_BACK_PORCH;
reg [7:0]H_FRONT_PORCH;
reg [15:0]V_RES;
reg [7:0]V_PULSE_WIDTH;
reg [7:0]V_BACK_PORCH;
reg [7:0]V_FRONT_PORCH;
reg [5:0]PIXEL_SIZE;
reg [31:0]VRAM_BASE_ADDRESS;
/* Here we select configuration values between dinamic configuration and static configuration. */
reg [10:0]h_res_int;
reg [7:0]h_pulse_width_int;
reg [7:0]h_back_porch_int;
reg [7:0]h_front_porch_int;
reg [10:0]v_res_int;
reg [7:0]v_pulse_width_int;
reg [7:0]v_back_porch_int;
reg [7:0]v_front_porch_int;
wire [5:0]pixel_size_int = (DINAMIC_CONFIG == "TRUE") ? PIXEL_SIZE : PIXEL_SIZE_CONF;
reg hsynk_inverted_int;
reg vsynk_inverted_int;
reg [12:0]h_cnt;
reg [12:0]v_cnt;
reg data_enable_inverted_int;
wire [31:0]vram_base_address_int = (DINAMIC_CONFIG == "TRUE") ? VRAM_BASE_ADDRESS : VRAM_BASE_ADDRESS_CONF;
always @ *
begin
	if(DISPLAY_CFG == "640_480_60_CRT_27_17_Mhz")
	begin
		h_res_int 				= 640;
		h_back_porch_int 		= 48;
		h_front_porch_int 		= 16;
		h_pulse_width_int	 	= 96;
		v_res_int 				= 480;
		v_back_porch_int 		= 33;
		v_front_porch_int 		= 10;
		v_pulse_width_int 		= 2;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "640_480_60_DISPLAY_24_20_Mhz")
	begin
		h_res_int 				= 640;
		h_back_porch_int 		= 72;
		h_front_porch_int 		= 24;
		h_pulse_width_int	 	= 32;
		v_res_int 				= 480;
		v_back_porch_int 		= 32;
		v_front_porch_int 		= 10;
		v_pulse_width_int 		= 3;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "720_480_60_DISPLAY_27_00_Mhz")
	begin
		h_res_int 				= 720;
		h_back_porch_int 		= 60;
		h_front_porch_int 		= 16;
		h_pulse_width_int	 	= 62;
		v_res_int 				= 480;
		v_back_porch_int 		= 30;
		v_front_porch_int 		= 9;
		v_pulse_width_int 		= 6;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "800_600_60_DISPLAY_40_00_Mhz")
	begin
		h_res_int 				= 800;
		h_back_porch_int 		= 88;
		h_front_porch_int 		= 40;
		h_pulse_width_int	 	= 128;
		v_res_int 				= 600;
		v_back_porch_int 		= 23;
		v_front_porch_int 		= 4;
		v_pulse_width_int 		= 5;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "1024_768_60_DISPLAY_65_00_Mhz")
	begin
		h_res_int 				= 1024;
		h_back_porch_int 		= 160;
		h_front_porch_int 		= 24;
		h_pulse_width_int	 	= 136;
		v_res_int 				= 768;
		v_back_porch_int 		= 29;
		v_front_porch_int 		= 3;
		v_pulse_width_int 		= 6;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "1280_720_60_DISPLAY_74_25_Mhz")
	begin
		h_res_int 				= 1280;
		h_back_porch_int 		= 220;
		h_front_porch_int 		= 70;
		h_pulse_width_int	 	= 80;
		v_res_int 				= 720;
		v_back_porch_int 		= 25;
		v_front_porch_int 		= 3;
		v_pulse_width_int 		= 5;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "1400_1050_60_DISPLAY_119_00_Mhz")/* Working at 100Mhz pixel clock rate on -1 grade device */
	begin
		h_res_int 				= 1400;
		h_back_porch_int 		= 80;
		h_front_porch_int 		= 48;
		h_pulse_width_int	 	= 32;
		v_res_int 				= 1050;
		v_back_porch_int 		= 21;
		v_front_porch_int 		= 3;
		v_pulse_width_int 		= 6;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "1440_900_60_DISPLAY_106_50_Mhz")/* Working at 100Mhz pixel clock rate on -1 grade device */
	begin
		h_res_int 				= 1440;
		h_back_porch_int 		= 232;
		h_front_porch_int 		= 80;
		h_pulse_width_int	 	= 152;
		v_res_int 				= 900;
		v_back_porch_int 		= 25;
		v_front_porch_int 		= 3;
		v_pulse_width_int 		= 6;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "1680_1050_60_DISPLAY_146_25_Mhz")/* Not working (To fast, maybe will work on -2 grade devices) */
	begin
		h_res_int 				= 1680;
		h_back_porch_int 		= 280;
		h_front_porch_int 		= 104;
		h_pulse_width_int	 	= 176;
		v_res_int 				= 1050;
		v_back_porch_int 		= 30;
		v_front_porch_int 		= 3;
		v_pulse_width_int 		= 6;
		hsynk_inverted_int		= 1;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "1920_1080_60_DISPLAY_148_5_Mhz")/* Not working (To fast, maybe will work on -2 grade devices) */
	begin
		h_res_int 				= 1920;
		h_back_porch_int 		= 236;
		h_front_porch_int 		= 88;
		h_pulse_width_int	 	= 44;
		v_res_int 				= 1080;
		v_back_porch_int 		= 40;
		v_front_porch_int 		= 4;
		v_pulse_width_int 		= 5;
		hsynk_inverted_int		= 1;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	if(DISPLAY_CFG == "AT070TN92_60_LCD_33_26_Mhz")
	begin
		h_res_int 				= 800;
		h_back_porch_int 		= 44;
		h_front_porch_int 		= 210;
		h_pulse_width_int	 	= 2;
		v_res_int 				= 480;
		v_back_porch_int 		= 21;
		v_front_porch_int 		= 22;
		v_pulse_width_int 		= 2;
		hsynk_inverted_int		= 0;
		vsynk_inverted_int		= 0;
		data_enable_inverted_int= 0;
	end
	else
	begin
		h_res_int 				= (DINAMIC_CONFIG == "TRUE") ? H_RES : H_RES_CONF;
		h_back_porch_int 		= (DINAMIC_CONFIG == "TRUE") ? H_BACK_PORCH : H_BACK_PORCH_CONF;
		h_front_porch_int 		= (DINAMIC_CONFIG == "TRUE") ? H_FRONT_PORCH : H_FRONT_PORCH_CONF;
		h_pulse_width_int	 	= (DINAMIC_CONFIG == "TRUE") ? H_PULSE_WIDTH : H_PULSE_WIDTH_CONF;
		v_res_int 				= (DINAMIC_CONFIG == "TRUE") ? V_RES : V_RES_CONF;
		v_back_porch_int 		= (DINAMIC_CONFIG == "TRUE") ? V_BACK_PORCH : V_BACK_PORCH_CONF;
		v_front_porch_int 		= (DINAMIC_CONFIG == "TRUE") ? V_FRONT_PORCH : V_FRONT_PORCH_CONF;
		v_pulse_width_int 		= (DINAMIC_CONFIG == "TRUE") ? V_PULSE_WIDTH : V_PULSE_WIDTH_CONF;
		hsynk_inverted_int		= (DINAMIC_CONFIG == "TRUE") ? HSYNK_INVERTED : HSYNK_INVERTED_CONF;
		vsynk_inverted_int		= (DINAMIC_CONFIG == "TRUE") ? VSYNK_INVERTED : VSYNK_INVERTED_CONF;
		data_enable_inverted_int= (DINAMIC_CONFIG == "TRUE") ? DATA_ENABLE_INVERTED : DATA_ENABLE_INVERTED_CONF;
	end
end
/* Here we calculate the total area to count for vertical & horisontal display area. */
wire [16:0]h_total_area = h_pulse_width_int + h_back_porch_int + h_res_int + h_front_porch_int;
wire [16:0]v_total_area = v_pulse_width_int + v_back_porch_int + v_res_int + v_front_porch_int;
/* Here are the H, V and data_enable intermediate wires. */
reg lcd_h_synk_int;
reg lcd_v_synk_int;
reg data_enable_int;
/* Here we select to use direct or inverse H, V and data_enable signals. */
assign lcd_h_synk = hsynk_inverted_int ^ lcd_h_synk_int;
assign lcd_v_synk = vsynk_inverted_int ^ lcd_v_synk_int;
assign lcd_de = data_enable_inverted_int ^ data_enable_int;
/* This is the video ram counter, will contain the real address of the displayed pixel. */
reg [BUS_VRAM_ADDR_LEN-1:0]addr_vram_cnt;
/* This registers are the intermediate registers for the output RGB colors. */
reg [7:0]lcd_r_int;
reg [7:0]lcd_g_int;
reg [7:0]lcd_b_int;
/* Future use, for FIFO dma joob. */
wire fifo_almost_empty;
wire fifo_almost_full;
wire fifo_empty;
wire fifo_full;
wire fifo_read_error;
wire fifo_write_error;

wire fifo_write;
wire fifo_read = data_enable_int;
wire [31:0]fifo_data_in;
wire [31:0]fifo_data_out;
 
reg fifo_rst_int;
/* These registers are used only in dinamic configuration mode, and are used to store highest three bytes of the video ram base address to loar all 32 bit in one cicle. */
reg [7:0]tmp_reg_in_1;
reg [7:0]tmp_reg_in_2;
reg [7:0]tmp_reg_in_3;
/* At this moment we use BRAM video ram memory, further we will develop the external memory access from a DMA like IP. */
(* ram_style="block" *)
reg [PIXEL_SIZE_CONF-1:0] vmem [(DEDICATED_VRAM_SIZE ? DEDICATED_VRAM_SIZE - 1 : 0):0];
/* This is an intermediary register that stores the pixel data taken from VRAM untranslated. */
reg [31:0]vmem_out_int;
/* This register will store the decoded RGB pixel data from other formats like 565. */
reg [31:0]vmem_raster_int;
/* This register is used to store most significand byte to store 16 bit configuration registry. */
reg [7:0]ctrl_write_tmp;

always @ (posedge ctrl_clk or posedge rst)
begin
	if(rst)
	begin
		EN <= 0;
		H_RES <= 800;
		H_PULSE_WIDTH <= 2;
		H_BACK_PORCH <= 46;
		H_FRONT_PORCH <= 210;
		V_RES <= 480;
		V_PULSE_WIDTH <= 2;
		V_BACK_PORCH <= 23;
		V_FRONT_PORCH <= 22;
		PIXEL_SIZE <= 16;
		HSYNK_INVERTED <= 1;
		VSYNK_INVERTED <= 1;
		DATA_ENABLE_INVERTED <= 0;
	end
	else
	begin
		if(DEBUG == "" && DINAMIC_CONFIG == "TRUE")
		begin
			if(wr_int)
			begin
				case(ctrl_addr[3:0])
				`LCD_CTRL: {HSYNK_INVERTED, VSYNK_INVERTED, DATA_ENABLE_INVERTED, EN} <= ctrl_data_in;
				`LCD_H_RES_LOW:
				begin
					H_RES <= {ctrl_write_tmp, ctrl_data_in};
				end
				`LCD_H_RES_HIGH: ctrl_write_tmp <= ctrl_data_in;
				`LCD_H_PULSE_WIDTH: H_PULSE_WIDTH <= ctrl_data_in;
				`LCD_H_BACK_PORCH : H_BACK_PORCH <= ctrl_data_in;
				`LCD_H_FRONT_PORCH: H_FRONT_PORCH <= ctrl_data_in;
				`LCD_V_RES_LOW:
				begin
					V_RES <= {ctrl_write_tmp, ctrl_data_in};
				end
				`LCD_V_RES_HIGH: ctrl_write_tmp <= ctrl_data_in;
				`LCD_V_PULSE_WIDTH: V_PULSE_WIDTH <= ctrl_data_in;
				`LCD_V_BACK_PORCH: V_BACK_PORCH <= ctrl_data_in;
				`LCD_V_FRONT_PORCH: H_FRONT_PORCH <= ctrl_data_in;
				`LCD_PIXEL_SIZE: PIXEL_SIZE <= ctrl_data_in;
				`LCD_BASE_ADDR_BYTE0: 
				begin
					if(MASTER == "TRUE")
						VRAM_BASE_ADDRESS <= {tmp_reg_in_3, tmp_reg_in_2, tmp_reg_in_1, ctrl_data_in};
				end
				`LCD_BASE_ADDR_BYTE1: 
				begin
					if(MASTER == "TRUE")
						tmp_reg_in_1 <= ctrl_data_in;
				end
				`LCD_BASE_ADDR_BYTE2: 
				begin
					if(MASTER == "TRUE")
						tmp_reg_in_2 <= ctrl_data_in;
				end
				`LCD_BASE_ADDR_BYTE3: 
				begin
					if(MASTER == "TRUE")
						tmp_reg_in_3 <= ctrl_data_in;
				end
				endcase
			end
		end
	end
end
/* These two registers are used to in case of the pixel data write bus of 8 bit length, in case of 16 bit pixels, write low byte this byte will be written in the tmp_vmem_in_1 register, when write the high byte this 8 bit with 8 bit from tmp_vmem_in_1 will be written to vram at the specified address. */
reg [7:0]tmp_vmem_in_1;
reg [7:0]tmp_vmem_in_2;
/* This is a translator switch in case of 8 bit write/read pixel buss and 8/16/24 bit pixel width. */
wire [BUS_VRAM_ADDR_LEN-1:0]wram_addr_int = BUS_VRAM_DATA_LEN == 8 && pixel_size_int == 16 ? vmem_addr[BUS_VRAM_ADDR_LEN-1:1] : 
					BUS_VRAM_DATA_LEN == 8 && pixel_size_int == 24 ? vmem_addr[BUS_VRAM_ADDR_LEN-1:2] :
					vmem_addr;

always @ (posedge ctrl_clk)
begin
	if(MASTER != "TRUE" && DEBUG == "")
	begin
		if(vmem_wr && ~rd_int)
		begin
			if(BUS_VRAM_DATA_LEN == 8 && pixel_size_int == 16)
			begin
				if(vmem_addr[0])
					tmp_vmem_in_1 <= vmem_in;
				else
					vmem[wram_addr_int] <= {vmem_in, tmp_vmem_in_1};
			end
			else if(BUS_VRAM_DATA_LEN == 8 && pixel_size_int == 24 && PIXEL_SIZE_CONF >= 24)
			begin
				if(vmem_addr[1:0] == 2'h0)
					tmp_vmem_in_1 <= vmem_in;
				else if(vmem_addr[1:0] == 2'h1)
					tmp_vmem_in_2 <= vmem_in;
				else
					vmem[wram_addr_int] <= {vmem_in, tmp_vmem_in_2, tmp_vmem_in_1};
			end
			else if((BUS_VRAM_DATA_LEN == 16 && pixel_size_int == 16) || (BUS_VRAM_DATA_LEN == 8 && pixel_size_int == 8))
				vmem[wram_addr_int] <= vmem_in;
			else if(BUS_VRAM_DATA_LEN == 32 && pixel_size_int == 24 && PIXEL_SIZE_CONF == 24)
				vmem[wram_addr_int] <= vmem_in;
		end
		vmem_out_int <= vmem[wram_addr_int];
	end
end
/* This is an intermediate register that store the high 8 bits from 16 bit register when lower 8 bits from that registers are read. */
reg [BUS_VRAM_DATA_LEN-1:0]vmem_out_tmp;

always @ *
begin
	if(DEBUG == "" && DINAMIC_CONFIG == "TRUE")
	begin
		if(rd_int && ~vmem_wr)
		begin
			case(ctrl_addr[3:0])
			`LCD_CTRL: ctrl_data_out <= {4'h0, HSYNK_INVERTED, VSYNK_INVERTED, DATA_ENABLE_INVERTED, EN};
			`LCD_H_RES_LOW: ctrl_data_out <= H_RES[7:0];
			`LCD_H_RES_HIGH: ctrl_data_out <= H_RES[15:8];
			`LCD_H_PULSE_WIDTH: ctrl_data_out <= H_PULSE_WIDTH;
			`LCD_H_BACK_PORCH: ctrl_data_out <= H_BACK_PORCH;
			`LCD_H_FRONT_PORCH: ctrl_data_out <= H_FRONT_PORCH;
			`LCD_V_RES_LOW: ctrl_data_out <= V_RES[7:0];
			`LCD_V_RES_HIGH: ctrl_data_out <= H_RES[15:8];
			`LCD_V_PULSE_WIDTH: ctrl_data_out <= V_PULSE_WIDTH;
			`LCD_V_BACK_PORCH: ctrl_data_out <= V_BACK_PORCH;
			`LCD_V_FRONT_PORCH: ctrl_data_out <= H_FRONT_PORCH;
			`LCD_PIXEL_SIZE: ctrl_data_out <= PIXEL_SIZE;
			`LCD_BASE_ADDR_BYTE0: 
			begin
				if(MASTER == "TRUE")
					ctrl_data_out <= VRAM_BASE_ADDRESS[7:0];
			end
			`LCD_BASE_ADDR_BYTE1: 
			begin
				if(MASTER == "TRUE")
					ctrl_data_out <= VRAM_BASE_ADDRESS[15:8];
			end
			`LCD_BASE_ADDR_BYTE2: 
			begin
				if(MASTER == "TRUE")
					ctrl_data_out <= VRAM_BASE_ADDRESS[23:16];
			end
			`LCD_BASE_ADDR_BYTE3: 
			begin
				if(MASTER == "TRUE")
					ctrl_data_out <= VRAM_BASE_ADDRESS[31:24];
			end
			endcase
		end
		else
			ctrl_data_out <= 8'h00;
	end
	else
		ctrl_data_out <= 8'h00;

	if(MASTER != "TRUE" && DEBUG == "")
	begin
		if(BUS_VRAM_DATA_LEN == 8 && pixel_size_int == 16)
		begin
			if(vmem_addr[0])
				vmem_out_tmp <= vmem_out_int[15:8];
			else
				vmem_out_tmp <= vmem_out_int[7:0];
		end
		else if(BUS_VRAM_DATA_LEN == 8 && pixel_size_int == 24 && PIXEL_SIZE_CONF >= 24)
		begin
			if(vmem_addr[1:0] == 2'h0)
				vmem_out_tmp <= vmem_out_int[7:0];
			else if(vmem_addr[1:0] == 2'h1)
				vmem_out_tmp <= vmem_out_int[15:8];
			else if(vmem_addr[1:0] == 2'h2)
				vmem_out_tmp <= vmem_out_int[23:16];
			else
				vmem_out_tmp <= 8'h00;
		end
		else
			vmem_out_tmp <= vmem_out_int;
	end
end
/* This is the vmem data output switch to make it three state when the vram memory is not selected by the processor. */
assign vmem_out = (vmem_rd && ~vmem_wr) ? (MASTER == "TRUE" ? 8'h00 : vmem_out_tmp) : 8'h00;

reg [7:0]cnt_colors;

always @ (posedge lcd_clk or posedge rst)
begin
	if(rst)
	begin
		if(MASTER == "TRUE")
			addr_vram_cnt <= vram_base_address_int;
		else
			addr_vram_cnt <= 'h0;
		h_cnt <= 'h0;
		v_cnt <= 'h0;
		if(DEBUG == "PATERN_RASTER")
			cnt_colors <= 'h0;
	end
	else
	begin
		h_cnt <= h_cnt + 1;
		if(data_enable_int)
		begin
			addr_vram_cnt <= addr_vram_cnt + 1;
		end
		if(h_cnt == h_total_area)
		begin
			h_cnt <= 'h0;
			v_cnt <= v_cnt + 1;
			if(v_cnt == v_total_area)
			begin
				v_cnt <= 'h0;
				if(MASTER == "TRUE")
					addr_vram_cnt <= vram_base_address_int;
				else
					addr_vram_cnt <= 'h0;
				if(DEBUG == "PATERN_RASTER")
					cnt_colors <= cnt_colors + 1;
			end
		end
		if(MASTER != "TRUE")
			vmem_raster_int <= vmem[addr_vram_cnt];
	end
end

always @ *
begin
	if(MASTER == "TRUE")
		vmem_raster_int = color_data_in;
	if(pixel_size_int == 8)
	begin
		lcd_r_int = {vmem_raster_int[2:0], 5'h0};
		lcd_g_int = {vmem_raster_int[4:3], 6'h0};
		lcd_b_int = {vmem_raster_int[7:5], 5'h0};
	end 
	else if(pixel_size_int == 16)
	begin
		lcd_r_int = {vmem_raster_int[4:0], 3'h0};
		lcd_g_int = {vmem_raster_int[10:5], 2'h0};
		lcd_b_int = {vmem_raster_int[15:11], 3'h0};
	end 
	else
	begin
		lcd_r_int = vmem_raster_int[7:0];
		lcd_g_int = vmem_raster_int[15:8];
		lcd_b_int = vmem_raster_int[23:16];
	end 
end

always @ *
begin
	lcd_h_synk_int <= h_cnt < h_pulse_width_int;
	lcd_v_synk_int <= v_cnt < v_pulse_width_int;
	data_enable_int <= h_cnt >= h_pulse_width_int + h_back_porch_int && h_cnt < h_pulse_width_int + h_back_porch_int + h_res_int && v_cnt >= v_pulse_width_int + v_back_porch_int && v_cnt < v_pulse_width_int + v_back_porch_int + v_res_int;

	fifo_rst_int <= &(~{h_cnt, v_cnt});
end
/* Here we select between debug mode and vram mode pixel display. */
assign lcd_r = (DEBUG == "PATERN_RASTER") ? h_cnt + cnt_colors : lcd_r_int;
assign lcd_g = (DEBUG == "PATERN_RASTER") ? h_cnt + v_cnt + cnt_colors : lcd_g_int;
assign lcd_b = (DEBUG == "PATERN_RASTER") ? h_cnt + v_cnt + v_cnt + cnt_colors : lcd_b_int; // RB

assign h_cnt_out = h_cnt - (h_pulse_width_int + h_back_porch_int);
assign v_cnt_out = v_cnt - (v_pulse_width_int + v_back_porch_int);

/* This is a generic custom made fifo that will work on every platform. */
/*fifo # (
	.DEPTH(FIFO_DEPTH),
	.DATA_WIDTH(PIXEL_SIZE_CONF),
	.ALMOST_EMPTY(FIFO_DEPTH / 4),
	.ALMOST_FULL(FIFO_DEPTH - (FIFO_DEPTH / 4))
	)fifo_inst(
	.rst(rst | fifo_rst_int),
	.wr_clk(ctrl_clk),
	.wr_en(fifo_write),
	.data_in(fifo_data_in),
	.rd_clk(lcd_clk),
	.rd_en(fifo_read),
	.data_out(fifo_data_out),
	.empty(fifo_empty),
	.full(fifo_full),
	.almost_empty(fifo_almost_empty),
	.almost_full(fifo_almost_full),
	.wr_err(fifo_write_error),
	.rd_err(fifo_read_error)
	);*/

endmodule
