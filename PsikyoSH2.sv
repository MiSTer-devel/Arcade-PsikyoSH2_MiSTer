//============================================================================
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

	import ARCADE_SWITCHES_PKG::*;

	assign ADC_BUS  = 'Z;
	assign {UART_RTS, UART_TXD, UART_DTR} = 0;
	assign BUTTONS   = {1'b0,osd_btn};
	assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
	assign USER_OUT = 'Z;

	assign AUDIO_S = 1;
	assign AUDIO_MIX = '0;
	assign HDMI_FREEZE = 0;
	assign VGA_DISABLE = 0;
	
	assign LED_DISK  = 0;
	assign LED_POWER = 0;
	assign LED_USER  = 0;
	assign VGA_SCALER = 0;
	assign HDMI_BLACKOUT = 1;

	///////////////////////////////////////////////////
	//
	// Status Bit Map:
	//             Upper                             Lower              
	// 0         1         2         3          4         5         6   	   7         8         9
	// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
	// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
	// XXXXXXXXXXXXXX  XXXX             XXXXXX
	
	`include "build_id.v"
	localparam CONF_STR = {
		"Arcade-PsikyoSH2;;",
`ifdef DEBUG
		"FS1,BIN,Load bios;",
		"FS0,BIN,Load cartridge;",
		"-;",
		"O[32],Ver,0,1;",
`endif
		"-;",
		"O[16],Autosave NVRAM,Off,On;",
		"D0T[17],Save NVRAM;",
		"-;",
		"O[19:18],Pause,Off,OSD,On;",
		"-;",
		
		"DIP;",
		"-;",
	
		"P1,Audio & Video;",
		"P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
		"P1O[13:11],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
		"P1-;",
	
		"D1P1O[4:3],Rotate,No,CCW,CW;",
		"D1P1O[5],Flip 180,Off,On;",
		"D2P1O[10],Two screen,Off,On;",
		"P1O[8:6],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer,HV-Integer;",
		"P1-;",
		"P1O[9],Audio,Mono,Stereo;",
		"-;",
		
`ifdef DEBUG
		"O[20],Debug port,Off,On;",
`endif

		"P2,Debug;",
		"P2O[37:33],Hsync offs,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
		"-;",

		"R0,Reset;",
		"J1,B1,B2,B3,Start,Coin,Test,Service;",
		"V,v",`BUILD_DATE
	};


	wire [127:0] status;
	wire [ 15:0] menumask;
	wire [  1:0] buttons;
	wire [ 31:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
	wire [  7:0] joy0_x0,joy0_y0,joy0_x1,joy0_y1,joy1_x0,joy1_y0,joy1_x1,joy1_y1;
	wire         ioctl_download,ioctl_upload;
	wire         ioctl_upload_req;
	wire         ioctl_wr,ioctl_rd;
	wire [ 25:0] ioctl_addr;
	wire [  7:0] ioctl_data,ioctl_din;
	wire [  7:0] ioctl_index;
	reg          ioctl_wait = 0;
	
	reg  [ 31:0] sd_lba = '0;
	reg          sd_rd = 0;
	reg          sd_wr = 0;
	wire         sd_ack;
	wire [  7:0] sd_buff_addr;
	wire [ 15:0] sd_buff_dout;
	wire [ 15:0] sd_buff_din0;
	wire [ 15:0] sd_buff_din = 0;
	wire         sd_buff_wr;
	wire [  1:0] img_mounted;
	wire         img_readonly;
	wire [ 63:0] img_size;
	
	wire         forced_scandoubler;
	wire         new_vmode = 0;
	wire [ 10:0] ps2_key;
	wire [ 24:0] ps2_mouse;
	wire [ 15:0] ps2_mouse_ext;
	
	wire [ 64:0] RTC;
	
	wire [ 35:0] EXT_BUS;
	
	wire [ 21:0] gamma_bus;
	wire [ 15:0] sdram_sz;
	
	hps_io #(.CONF_STR(CONF_STR)) hps_io
	(
		.clk_sys(clk_sys),
		.HPS_BUS(HPS_BUS),
	
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.joystick_2(joystick_2),
		.joystick_3(joystick_3),
		.joystick_4(joystick_4),
		.joystick_l_analog_0({joy0_y0, joy0_x0}),
		.joystick_l_analog_1({joy1_y0, joy1_x0}),
		.joystick_r_analog_0({joy0_y1, joy0_x1}),
		.joystick_r_analog_1({joy1_y1, joy1_x1}),
	
		.buttons(buttons),
		.forced_scandoubler(forced_scandoubler),
		.new_vmode(new_vmode),
	
		.status(status),
		.status_in(status),
		.status_set(0),
		.status_menumask(menumask),
	
		.ioctl_download(ioctl_download),
		.ioctl_index(ioctl_index),
		.ioctl_upload(ioctl_upload),
		.ioctl_upload_req(ioctl_upload_req),
		.ioctl_upload_index(8'h04),
		.ioctl_addr(ioctl_addr),
		.ioctl_dout(ioctl_data),
		.ioctl_din(ioctl_din),
		.ioctl_wr(ioctl_wr),
		.ioctl_rd(ioctl_rd),
		.ioctl_wait(ioctl_wait),
	
		.sd_lba('{sd_lba}),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_buff_addr(sd_buff_addr),
		.sd_buff_dout(sd_buff_dout),
		.sd_buff_din('{sd_buff_din}),
		.sd_buff_wr(sd_buff_wr),
		.img_mounted(img_mounted),
		.img_readonly(img_readonly),
		.img_size(img_size),
	
		.gamma_bus(gamma_bus),
		.sdram_sz(sdram_sz),
	
		.ps2_key(ps2_key),
		.ps2_mouse(ps2_mouse),
		.ps2_mouse_ext(ps2_mouse_ext),
		
		.RTC(RTC),
	
		.EXT_BUS(EXT_BUS)
	);
	
	assign menumask = {~ps4_board, ~(ps3_board|ps5_board), 1'b0};
	
`ifdef DEBUG
	wire cart_download = ioctl_download & (ioctl_index[5:0] == 6'h0);
	wire bios_download = ioctl_download & (ioctl_index[5:0] == 6'h1);
`endif
	wire conf_download = ioctl_download & (ioctl_index[5:0] == 6'h2);
	wire hsconf_download = ioctl_download & (ioctl_index[5:0] == 6'h3);
	wire nvram_download = ioctl_download & (ioctl_index[5:0] == 6'h4);
	wire nvram_upload = ioctl_upload & (ioctl_index[5:0] == 6'h4);
	
	reg osd_btn = 0;

	///////////////////////////////////////////////////
	wire clk_sys, clk_ram, locked;
	pll pll
	(
		.refclk(CLK_50M),
		.rst(0),
		.outclk_0(clk_sys),
		.outclk_1(clk_ram),
		.locked(locked)
	);
	
	wire reset = RESET | status[0] | buttons[1];
	
	reg loader_rst = 0;
	reg download = 0;
`ifdef DEBUG
	always @(posedge clk_sys) begin		
		download <= bios_download || cart_download;
	end
`endif
	wire rst_sys = reset | download | loader_rst;
	
	//[1:0] - ver: 0-PS3,1-PS5,2-PS4
	//[5:4] - input mode: 1,2,3,4 push switches
	//[6] - input mode: mahjong panel
	reg  [7:0] BOARD_CONF = 8'h00;
	always @(posedge clk_sys) begin
		if (conf_download && ioctl_wr && ioctl_addr[8:0] == 9'h000) begin
			BOARD_CONF <= ioctl_data[7:0];
		end
	end
	wire ps3_board = (BOARD_CONF[1:0] == 2'h0);
	wire ps5_board = (BOARD_CONF[1:0] == 2'h1);
	wire ps4_board = (BOARD_CONF[1:0] == 2'h2);
	localparam [2:0] INPUT_1_PUSH_SWITCH = 3'h0;
	localparam [2:0] INPUT_2_PUSH_SWITCH = 3'h1;
	localparam [2:0] INPUT_3_PUSH_SWITCH = 3'h2;
	localparam [2:0] INPUT_4_PUSH_SWITCH = 3'h3;
	localparam [2:0] INPUT_MAHJONG       = 3'h4;
	localparam PCB_PLAYERS       = 4;
	localparam PCB_PUSH_SWITCHES = 4;
	localparam PCB_PLAYER_SW_WIDTH = P_SW_PUSH_BASE + PCB_PUSH_SWITCHES;
	
	reg [7:0] dip_sw = '0;
	always @(posedge clk_sys) begin
		if (ioctl_wr && (ioctl_index == 8'd254) && !ioctl_addr)
			dip_sw <= ioctl_data[7:0];
	end
	
	wire [7:0] p0,p1,p2,p3,p4,p5,p6,p7,pA_o;
	cabinet_sw_t key_cabinet_sw;
	wire [PCB_PLAYER_SW_WIDTH-1:0] key_p1_sw,key_p2_sw,key_p3_sw,key_p4_sw;
	wire       key_pause;
	wire key_service_sw = key_p1_sw[P_SW_SERVICE] | key_p2_sw[P_SW_SERVICE];
	wire [3:0] key_p1_system = {
		key_service_sw,
		key_cabinet_sw[C_SW_TEST],
		key_cabinet_sw[C_SW_COIN1],
		key_p1_sw[P_SW_START]
	};
	wire [3:0] key_p2_system = {
		1'b0,
		1'b0,
		key_cabinet_sw[C_SW_COIN2],
		key_p2_sw[P_SW_START]
	};
	wire [3:0] key_p3_system = {
		1'b0,
		1'b0,
		key_cabinet_sw[C_SW_COIN3],
		key_p3_sw[P_SW_START]
	};
	wire [3:0] key_p4_system = {
		1'b0,
		1'b0,
		key_cabinet_sw[C_SW_COIN4],
		key_p4_sw[P_SW_START]
	};

	// The keyboard mapper reports generic arcade switches. Convert those into
	// this core's existing joystick bit layout before the board-port packing.
	function automatic [31:0] player_sw_to_core_joy;
		input [PCB_PLAYER_SW_WIDTH-1:0] player_sw;
	begin
		player_sw_to_core_joy = '0;
		player_sw_to_core_joy[0] = player_sw[P_SW_RIGHT];
		player_sw_to_core_joy[1] = player_sw[P_SW_LEFT];
		player_sw_to_core_joy[2] = player_sw[P_SW_DOWN];
		player_sw_to_core_joy[3] = player_sw[P_SW_UP];
		player_sw_to_core_joy[4] = player_sw[P_SW_PUSH1];
		player_sw_to_core_joy[5] = player_sw[P_SW_PUSH2];
		player_sw_to_core_joy[6] = player_sw[P_SW_PUSH3];
		player_sw_to_core_joy[7] = player_sw[P_SW_PUSH4];
	end
	endfunction

	function automatic [31:0] merge_arcade_input;
		input [31:0] joy;
		input [PCB_PLAYER_SW_WIDTH-1:0] player_sw;
		input [ 3:0] key_system; // {Service, Test, Coin, Start}
		input [ 2:0] input_mode;
		reg   [31:0] merged;
		reg   [31:0] sw_joy;
	begin
		merged = joy;
		sw_joy = player_sw_to_core_joy(player_sw);
		case (input_mode)
			INPUT_1_PUSH_SWITCH: begin // 1 push switch, then Start/Coin/Test/Service
				merged[4:0] = merged[4:0] | sw_joy[4:0];
				merged[8:5] = merged[8:5] | key_system;
			end
			INPUT_2_PUSH_SWITCH: begin // 2 push switches, then Start/Coin/Test/Service
				merged[5:0] = merged[5:0] | sw_joy[5:0];
				merged[9:6] = merged[9:6] | key_system;
			end
			INPUT_3_PUSH_SWITCH: begin // 3 push switches, then Start/Coin/Test/Service
				merged[6:0]  = merged[6:0]  | sw_joy[6:0];
				merged[10:7] = merged[10:7] | key_system;
			end
			INPUT_4_PUSH_SWITCH: begin // 4 push switches, then Start/Coin/Test/Service
				merged[7:0]  = merged[7:0]  | sw_joy[7:0];
				merged[11:8] = merged[11:8] | key_system;
			end
			default: begin
			end
		endcase
		merge_arcade_input = merged;
	end
	endfunction

	mame_keyboard_switches #(
		.PLAYERS(PCB_PLAYERS),
		.PUSH_SWITCHES(PCB_PUSH_SWITCHES),
		.PLAYER_SW_WIDTH(PCB_PLAYER_SW_WIDTH)
	) mame_keyboard_switches_inst
	(
		.clk(clk_sys),
		.reset(reset),
		.ps2_key(ps2_key),
		.cabinet_sw(key_cabinet_sw),
		.p1_sw(key_p1_sw),
		.p2_sw(key_p2_sw),
		.p3_sw(key_p3_sw),
		.p4_sw(key_p4_sw),
		.pause(key_pause)
	);

	always_comb begin
		reg [5:0] mp1_key,mp2_key;
		reg [31:0] joy0,joy1,joy2,joy3;
	
		{mp1_key,mp2_key} = '0;
		{joy0,joy1,joy2,joy3} = {joystick_0,joystick_1,joystick_2,joystick_3};
		{p0,p1,p2,p3,p4,p5,p6,p7} = '1;
		if (BOARD_CONF[6:4] != INPUT_MAHJONG) begin
			joy0 = merge_arcade_input(joystick_0, key_p1_sw, key_p1_system, BOARD_CONF[6:4]);
			joy1 = merge_arcade_input(joystick_1, key_p2_sw, key_p2_system, BOARD_CONF[6:4]);
			joy2 = merge_arcade_input(joystick_2, key_p3_sw, key_p3_system, BOARD_CONF[6:4]);
			joy3 = merge_arcade_input(joystick_3, key_p4_sw, key_p4_system, BOARD_CONF[6:4]);
		end

		if (ps3_board || ps5_board) begin	//PS3/PS5
			if (BOARD_CONF[6:4] == INPUT_1_PUSH_SWITCH) begin
				p0 = ~{joy0[3],joy0[2],joy0[0],joy0[1],joy0[4],2'b00,joy0[5]};
				p1 = ~{joy1[3],joy1[2],joy1[0],joy1[1],joy1[4],2'b00,joy1[5]};
				p2 = 8'hFF;
				p3 = ~{1'b0,~dip_sw[6],joy0[7],joy0[8],2'b11,joy1[6],joy0[6]};
			end
			else if (BOARD_CONF[6:4] == INPUT_2_PUSH_SWITCH) begin
				p0 = ~{joy0[3],joy0[2],joy0[0],joy0[1],joy0[4],joy0[5],1'b0,joy0[6]};
				p1 = ~{joy1[3],joy1[2],joy1[0],joy1[1],joy1[4],joy1[5],1'b0,joy1[6]};
				p2 = 8'hFF;
				p3 = ~{1'b0,~dip_sw[6],joy0[8],joy0[9],2'b11,joy1[7],joy0[7]};
			end
			else if (BOARD_CONF[6:4] == INPUT_3_PUSH_SWITCH) begin
				p0 = ~{joy0[3],joy0[2],joy0[0],joy0[1],joy0[4],joy0[5],joy0[6],joy0[7]};
				p1 = ~{joy1[3],joy1[2],joy1[0],joy1[1],joy1[4],joy1[5],joy1[6],joy1[7]};
				p2 = 8'hFF;
				p3 = ~{1'b0,~dip_sw[6],joy0[9],joy0[10],2'b11,joy1[8],joy0[8]};
			end
			else if (BOARD_CONF[6:4] == INPUT_4_PUSH_SWITCH) begin
				p0 = ~{joy0[3],joy0[2],joy0[0],joy0[1],joy0[4],joy0[5],1'b0,joy0[8]};
				p1 = ~{joy1[3],joy1[2],joy1[0],joy1[1],joy1[4],joy1[5],1'b0,joy1[8]};
				p2 = ~{joy0[6],joy0[7],2'b00,joy1[6],joy1[7],2'b00};
				p3 = ~{1'b0,~dip_sw[6],joy0[10],joy0[11],2'b11,joy1[9],joy0[9]};
			end
			else if (BOARD_CONF[6:4] == INPUT_MAHJONG) begin //mahjong panel
				if      (joystick_0[ 4]) {p0,p1} = ~16'h8080;
				else if (joystick_0[ 5]) {p0,p1} = ~16'h8040;
				else if (joystick_0[ 6]) {p0,p1} = ~16'h8010;
				else if (joystick_0[ 7]) {p0,p1} = ~16'h8020;
				else if (joystick_0[ 8]) {p0,p1} = ~16'h4080;
				else if (joystick_0[ 9]) {p0,p1} = ~16'h4040;
				else if (joystick_0[10]) {p0,p1} = ~16'h4010;
				else if (joystick_0[11]) {p0,p1} = ~16'h4020;
				else if (joystick_0[12]) {p0,p1} = ~16'h1080;
				else if (joystick_0[13]) {p0,p1} = ~16'h1040;
				else if (joystick_0[14]) {p0,p1} = ~16'h1010;
				else if (joystick_0[15]) {p0,p1} = ~16'h1020;
				else if (joystick_0[16]) {p0,p1} = ~16'h2080;
				else if (joystick_0[17]) {p0,p1} = ~16'h2040;
				else if (joystick_0[18]) {p0,p1} = ~16'h0880;
				else if (joystick_0[19]) {p0,p1} = ~16'h2020;
				else if (joystick_0[20]) {p0,p1} = ~16'h2010;
				else if (joystick_0[21]) {p0,p1} = ~16'h0840;
				else if (joystick_0[22]) {p0,p1} = ~16'h0810;
				else if (joystick_0[23]) {p0,p1} = ~16'h0480;
				else {p0,p1} = ~16'h0000;
				p3 = ~{1'b0,~dip_sw[6],joystick_0[25],joystick_0[26],2'b11,joystick_1[24],joystick_0[24]};
			end
		end
		else begin	//PS4 
			if (BOARD_CONF[6:4] == INPUT_3_PUSH_SWITCH) begin //3 push switches
				p0 = ~{joy0[7],joy0[6],joy0[5],joy0[4],joy0[0],joy0[1],joy0[2],joy0[3]};
				p1 = ~{joy1[7],joy1[6],joy1[5],joy1[4],joy1[0],joy1[1],joy1[2],joy1[3]};
				p2 = 8'hFF;
				p3 = ~{joy3[10]|joy2[10],~dip_sw[6],joy0[9],joy1[10]|joy0[10],joy3[8],joy2[8],joy1[8],joy0[8]};
				
				p4 = ~{joy2[7],joy2[6],joy2[5],joy2[4],joy2[0],joy2[1],joy2[2],joy2[3]};
				p5 = ~{joy3[7],joy3[6],joy3[5],joy3[4],joy3[0],joy3[1],joy3[2],joy3[3]};
				p6 = 8'hFF;
				p7 = 8'hFF;
			end
			else if (BOARD_CONF[6:4] == INPUT_4_PUSH_SWITCH) begin //4 push switches
				p0 = ~{joy0[8],3'b000,joy0[7],joy0[6],joy0[5],joy0[4]};
				p1 = ~{joy1[8],3'b000,joy1[7],joy1[6],joy1[5],joy1[4]};
				p2 = 8'hFF;
				p3 = ~{1'b0,~dip_sw[6],joy0[10],joy0[11],2'b11,joy1[9],joy0[9]};
				
				p4 = ~{joy2[8],3'b000,joy2[7],joy2[6],joy2[5],joy2[4]};
				p5 = ~{joy3[8],3'b000,joy3[7],joy3[6],joy3[5],joy3[4]};
				p6 = 8'hFF;
				p7 = ~{joy3[11]|joy2[11],~dip_sw[6],joy0[10],joy1[11]|joy1[11],joy3[9],joy2[9],joy1[9],joy0[9]};
			end
			else if (BOARD_CONF[6:4] == INPUT_MAHJONG) begin //mahjong panel
				if (pA_o[0]) mp1_key = {joystick_0[23],joystick_0[20],joystick_0[16],joystick_0[12],joystick_0[ 8],joystick_0[4]};
				if (pA_o[1]) mp1_key = {joystick_0[24],joystick_0[21],joystick_0[17],joystick_0[13],joystick_0[ 9],joystick_0[5]};
				if (pA_o[2]) mp1_key = {1'b0          ,joystick_0[22],joystick_0[18],joystick_0[14],joystick_0[10],joystick_0[6]};
				if (pA_o[3]) mp1_key = {1'b0          ,1'b0          ,joystick_0[19],joystick_0[15],joystick_0[11],joystick_0[7]};
				p0 = ~{2'b00,mp1_key};
				p1 = 8'hFF;
				p2 = 8'hFF;
				p3 = ~{joystick_1[27],~dip_sw[6],joystick_0[26],joystick_0[27],1'b0,joystick_1[25],1'b0,joystick_0[25]};
				
				if (pA_o[0]) mp2_key = {joystick_1[23],joystick_1[20],joystick_1[16],joystick_1[12],joystick_1[ 8],joystick_1[4]};
				if (pA_o[1]) mp2_key = {joystick_1[24],joystick_1[21],joystick_1[17],joystick_1[13],joystick_1[ 9],joystick_1[5]};
				if (pA_o[2]) mp2_key = {1'b0          ,joystick_1[22],joystick_1[18],joystick_1[14],joystick_1[10],joystick_1[6]};
				if (pA_o[3]) mp2_key = {1'b0          ,1'b0          ,joystick_1[19],joystick_1[15],joystick_1[11],joystick_1[7]};
				p4 = ~{2'b00,mp2_key};
				p5 = 8'hFF;
				p6 = 8'hFF;
				p7 = ~{joystick_1[27],~dip_sw[6],joystick_0[26],joystick_0[27],1'b0,joystick_1[25],1'b0,joystick_0[25]};
			end
		end
	end
	
	wire [20: 1] ROM_A;
	wire [31: 0] ROM_D;
	wire         PROM_CE_N;
	wire         DROM_CE_N;
	wire         ROM_OE_N;
	
	wire [19: 2] DRAM_A;
	wire [31: 0] DRAM_DI;
	wire [31: 0] DRAM_DO;
	wire [ 3: 0] DRAM_WE_N;
	wire         DRAM_RD_N;
	wire         DRAM_CE_N;
	
	wire         MEM_WAIT_N;
	
	wire [24: 0] GFX_ROM_A;
	wire [31: 0] GFX_ROM_D;
	wire         GFX_ROM_RD_N;
	
	wire [22: 0] SOUND_ROM_A;
	wire [ 7: 0] SOUND_ROM_D;
	wire         SOUND_ROM_RD_N;
	
	wire [ 7: 0] EEP_MEM_A;
	wire [ 7: 0] EEP_MEM_Q;
	wire         EEP_MEM_WREN;
	wire [ 7: 0] EEP_MEM_DATA;
	
	wire [ 7: 0] R, G, B;
	wire         HS_N,VS_N;
	wire         DCLK1,DCLK2;
	wire         HBL_N, VBL_N;
	wire         DCE_R;
	wire         V240;
	wire [15: 0] SOUND_L;
	wire [15: 0] SOUND_R;
	
	PSH2 psh2
	(
		.CLK(clk_sys),
		.RST_N(~rst_sys),
		.EN(1'b1),
		
		.CE(1'b1),
		
		.RES_N(~status[0]),
		
		.ROM_A(ROM_A),
		.ROM_D(ROM_D),
		.PROM_CE_N(PROM_CE_N),
		.DROM_CE_N(DROM_CE_N),
		.ROM_OE_N(ROM_OE_N),
		
		.DRAM_A(DRAM_A),
		.DRAM_DI(DRAM_DI),
		.DRAM_DO(DRAM_DO),
		.DRAM_WE_N(DRAM_WE_N),
		.DRAM_RD_N(DRAM_RD_N),
		.DRAM_CE_N(DRAM_CE_N),
		
		.MEM_WAIT_N(MEM_WAIT_N),
		
		.GFX_ROM_A(GFX_ROM_A),
		.GFX_ROM_D(GFX_ROM_D),
		.GFX_ROM_RD_N(GFX_ROM_RD_N),
		
		.SOUND_ROM_A(SOUND_ROM_A),
		.SOUND_ROM_D(SOUND_ROM_D),
		.SOUND_ROM_RD_N(SOUND_ROM_RD_N),
		
		.EEP_MEM_A(EEP_MEM_A),
		.EEP_MEM_Q(EEP_MEM_Q),
		.EEP_MEM_WREN(EEP_MEM_WREN),
		.EEP_MEM_DATA(EEP_MEM_DATA),
		
		.R(R),
		.G(G),
		.B(B),
		.DCLK1(DCLK1),
		.DCLK2(DCLK2),
		.VS_N(VS_N),
		.HS_N(HS_N),
		.HBL_N(HBL_N),
		.VBL_N(VBL_N),
		.V240(V240),
		
		.SOUND_L(SOUND_L),
		.SOUND_R(SOUND_R),
		
		.P0(p0),
		.P1(p1),
		.P2(p2),
		.P3(p3),
		.P4(p4),
		.P5(p5),
		.P6(p6),
		.P7(p7),
		.PA_O(pA_o),
		.JP4({4'h0,dip_sw[3:0]}),
		
		.VER(BOARD_CONF[1:0]),
		
		.SCRN_EN(SCRN_EN),
		.HS_OFFS({{4{status[37]}},status[37:33]}),
		.SND_EN(SND_EN),
		.SND_MONO(~status[9])
		
`ifdef DEBUG
		,
		.DBG_PAUSE(DBG_BREAK)
`endif
	);

	assign AUDIO_L = SOUND_L;
	assign AUDIO_R = SOUND_R;

	
	//GFX/Sound ROM 
	//PS3/PS5 (GFX-0x0000000..0x3C00000,Sound-0x3C00000..0x3FFFFFF)
	//PS4 (GFX-0x0000000..0x3FFFFFF,Sound-0x4000000..0x47FFFFF)
	wire        sdr_rdy;
	wire [31:0] sdr_dout1;
	wire [15:0] sdr_dout2;
	sdram1 sdram1
	(
		.SDRAM_CLK(SDRAM_CLK),
		.SDRAM_A(SDRAM_A),
		.SDRAM_BA(SDRAM_BA),
		.SDRAM_DQ(SDRAM_DQ),
		.SDRAM_DQML(SDRAM_DQML),
		.SDRAM_DQMH(SDRAM_DQMH),
		.SDRAM_nCS(SDRAM_nCS),
		.SDRAM_nWE(SDRAM_nWE),
		.SDRAM_nRAS(SDRAM_nRAS),
		.SDRAM_nCAS(SDRAM_nCAS),
		.SDRAM_CKE(SDRAM_CKE),
		
		.clk(clk_ram),
		.init(status[0]),
		.init_done(sdr_rdy),
		.sync(loader_exec ? sdr_rom_wr : DCLK1),
	
		.waddr(sdr_rom_addr),
		.wr  (loader_exec),
		.din (sdr_rom_data),
		
		.raddr1(GFX_ROM_A[23:0]),
		.rd1 (~GFX_ROM_RD_N),
		.dout1(sdr_dout1),
		
		.raddr2(SOUND_ROM_A[22:1]),
		.rd2 (~SOUND_ROM_RD_N),
		.dout2(sdr_dout2),
		.m2(ps4_board)
	);
	assign GFX_ROM_D = sdr_dout1;
	assign SOUND_ROM_D = !SOUND_ROM_A[0] ? sdr_dout2[15:8] : sdr_dout2[7:0];

	//Prog/Data ROM, DRAM
	reg  [ 3: 0] loader_state = 0;
	reg          loader_exec = 0;
	reg  [26: 3] ddr_rom_addr;
	reg  [63: 0] ddr_rom_do;
	reg          ddr_rom_rd;
	wire         ddr_rom_busy;
	reg  [26: 3] sdr_rom_addr;
	reg  [63: 0] sdr_rom_data;
	reg          sdr_rom_wr;
	reg  [ 7: 1] eeprom_addr;
	reg  [15: 0] eeprom_data;
	reg          eeprom_wr;
	always @(posedge clk_sys) begin		
		reg nvram_load_skip = 0;
		
		if (reset) begin
			ddr_rom_addr <= '0;
			ddr_rom_rd <= 0;
			sdr_rom_addr <= '0;
			sdr_rom_wr <= 0;
			eeprom_addr <= '0;
			eeprom_wr <= 0;
			loader_state = 4'd1;
			loader_exec <= 0;
			loader_rst <= 1;
		end
		else if (sdr_rdy) begin
			ddr_rom_rd <= 0;
			sdr_rom_wr <= 0;
			eeprom_wr <= 0;
			case (loader_state)
				4'd0: begin
					loader_exec <= 0;
				end
				
				4'd1: begin
					ddr_rom_rd <= 1;
					loader_exec <= 1;
					loader_state = 4'd2;
				end
				
				4'd2: if (!ddr_rom_busy) begin
					sdr_rom_data <= ddr_rom_do;
					sdr_rom_wr <= 1;
					ddr_rom_addr <= ddr_rom_addr + 1'd1;
					ddr_rom_rd <= 1;
					loader_state = 4'd3;
				end
				
				4'd3,4'd4,4'd5,4'd6,4'd7,4'd8: begin
					loader_state = loader_state + 4'd1;
				end
				
				4'd9: begin
					sdr_rom_addr <= sdr_rom_addr + 1'd1;
					if (ddr_rom_addr == (ps4_board ? (27'h4800000>>3) : (27'h4000000>>3))) begin
						if (nvram_load_skip) begin
							loader_state = 4'd0; 
							loader_rst <= 0;
						end else begin
							loader_state = 4'd10; 
						end
					end
					else  begin
						loader_state = 4'd2;
					end
				end
				
				4'd10: if (!ddr_rom_busy) begin
					ddr_rom_addr <= 27'h4C00000>>3;
					ddr_rom_rd <= 1;
					loader_state = 4'd11;
				end
				
				4'd11: if (!ddr_rom_busy) begin
					eeprom_data <= ddr_rom_do[63:48];
					eeprom_wr <= 1;
					loader_state = 4'd12;
				end
				
				4'd12: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					eeprom_data <= ddr_rom_do[47:32];
					eeprom_wr <= 1;
					loader_state = 4'd13;
				end
				
				4'd13: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					eeprom_data <= ddr_rom_do[31:16];
					eeprom_wr <= 1;
					loader_state = 4'd14;
				end
				
				4'd14: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					eeprom_data <= ddr_rom_do[15:0];
					eeprom_wr <= 1;
					ddr_rom_addr <= ddr_rom_addr + 1'd1;
					ddr_rom_rd <= 1;
					loader_state = 4'd15;
				end
				
				4'd15: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					if (ddr_rom_addr[6:3] == 4'h0) begin
						loader_state = 4'd0; 
						loader_rst <= 0;
					end
					else  begin
						loader_state = 4'd11;
					end
				end
			endcase
			
		end
		
		if (nvram_download & ioctl_wr) nvram_load_skip <= 1;
	end
	
	wire [15: 0] drom_do;
	wire [31: 0] dram_do,prom_do;
	wire [ 7: 0] hsram_do;
	wire         dram_busy,prom_busy,drom_busy,bios_busy,hsram_busy;
	ddram ddram
	(
		.*,
		.clk(clk_ram),
		.rst(reset),
		
		//CPU bus (DRAM)
		.dram_addr(DRAM_A[19:2]),
		.dram_din (DRAM_DO),
		.dram_wr  (~{4{DRAM_CE_N}} & ~DRAM_WE_N),
		.dram_rd  (~DRAM_CE_N & ~DRAM_RD_N),
		.dram_dout(dram_do),
		.dram_busy(dram_busy),
	
		//CPU bus (PROG ROM)
		.prom_addr(ROM_A[19:2]),
		.prom_rd  (~PROM_CE_N & ~ROM_OE_N),
		.prom_dout(prom_do),
		.prom_busy(prom_busy),
	
		//CPU bus (DATA ROM)
		.drom_addr(ROM_A[20:1]),
		.drom_rd  (~DROM_CE_N & ~ROM_OE_N),
		.drom_dout(drom_do),
		.drom_busy(drom_busy),
	
		//PROG/DATA ROM load
`ifdef DEBUG
		.bios_addr(ioctl_addr[20:1]),
		.bios_din ({ioctl_data[7:0],ioctl_data[7:0]}),
		.bios_wr  ({2{bios_download & ioctl_wr}}),
`else
		.bios_addr('0),
		.bios_din ('0),
		.bios_wr  ('0),
`endif
		.bios_busy(bios_busy),
	
		//GFX/Sound ROM,EEPROM loader
		.rom_addr(ddr_rom_addr),
		.rom_rd  (ddr_rom_rd),
		.rom_dout(ddr_rom_do),
		.rom_busy(ddr_rom_busy),
		
		//hiscore RAM
		.hsram_addr(hs_ram_addr[19:0]),
		.hsram_din (hs_data_in),
		.hsram_wr  (hs_ram_write),
		.hsram_rd  (hs_ram_read),
		.hsram_dout(hsram_do),
		.hsram_busy(hsram_busy),
	
		//FB
		.fb_addr(fb_addr),
		.fb_din (fb_data),
		.fb_we  ({8{fb_we}}&fb_be),
		.fb_busy(fb_busy)
	);

	assign DRAM_DI = dram_do;
	assign ROM_D = !PROM_CE_N ? prom_do : {16'h0000,drom_do};
	assign MEM_WAIT_N = (OSD_STATUS && status[18]) || status[19] || key_pause ? 1'b0 :
	                    !DRAM_CE_N ? ~dram_busy : 
							  !PROM_CE_N ? ~prom_busy : ~drom_busy;
	
	
	//NVRAM/HiScore
	reg  [19: 0] hs_ram_addr;
	reg  [ 7: 0] hs_data_in;
	reg          hs_ram_write,hs_ram_read;
	reg  [ 7: 0] hs_ram_data_addr;
	reg  [ 0: 0] hs_ram_data_block;
	reg          hs_ram_data_wr;
	reg  [ 8: 0] hs_load_data_addr,hs_load_data_pos;
	reg          hs_load_data_wr;
	wire [25: 0] hs_load_addr = ioctl_addr - 26'h100;
		
	reg  [31: 0] HS_START_ADDR[2],HS_END_ADDR[2];
	reg  [15: 0] HS_LEN[2];
	reg  [ 7: 0] HS_START_DATA[2],HS_END_DATA[2];
	reg          HS_ENABLE = 1'b0;
	reg          HS_LAST_NUM;
	reg          HS_LOADED[2],HS_UPLOADED[2];
	reg  [ 1: 0] HS_MATCH[2];
	reg  [ 0: 0] HS_NUM;
	always @(posedge clk_sys) begin
		reg hsconf_download_old,nvram_download_old,nvram_upload_old,reset_old,hs_start_cond_old;
		reg [3:0] hs_state = 0;
		reg [0:0] HS_NUM;
		reg [7:0] DRAM_DO_BYTES[4];
		
		nvram_download_old <= nvram_download;
		nvram_upload_old <= nvram_upload;
		reset_old <= reset;
		
		//ram transfer
		hs_start_cond_old <= hs_start_cond;
		case (hs_state)
			4'd0: begin
				ioctl_wait <= 0;
			end
			
			4'd1: begin
				hs_ram_addr <= HS_START_ADDR[0][19:0];
				{hs_ram_data_block,hs_ram_data_addr} <= 9'h000;
				hs_state <= 4'd2;
			end
			
			4'd2: begin
				hs_ram_write <= 1;
				hs_state <= 4'd3;
			end
			
			4'd3: begin
				hs_ram_write <= 0;
				if (!hs_ram_write && !hsram_busy) begin
					hs_state <= 4'd4;
				end
			end
			
			4'd4: begin
				hs_ram_write <= 0;
				if (!hs_ram_write && !hsram_busy) begin
					if (hs_ram_addr == HS_END_ADDR[hs_ram_data_block][19:0]) begin
						if (hs_ram_data_block == HS_NUM) begin
							hs_state <= 4'd0;//idle
						end else begin
							hs_ram_addr <= HS_START_ADDR[hs_ram_data_block+1'd1][19:0];
							hs_ram_data_block <= hs_ram_data_block + 1'd1;
							hs_ram_data_addr <= '0;
							hs_state <= 4'd2;
						end
					end else begin
						hs_ram_addr <= hs_ram_addr + 1'd1;
						hs_ram_data_addr <= hs_ram_data_addr + 8'd1;
						hs_state <= 4'd2;
					end
				end
			end
			
			//
			4'd5: begin
				hs_ram_addr <= HS_START_ADDR[0][19:0];
				{hs_ram_data_block,hs_ram_data_addr} <= 9'h000;
				hs_state <= 4'd6;
			end
			
			4'd6: begin
				hs_ram_read <= 1;
				hs_state <= 4'd7;
			end
			
			4'd7: begin
				hs_ram_read <= 0;
				if (!hs_ram_read && !hsram_busy) begin
					hs_ram_data_wr <= 1;
					hs_state <= 4'd8;
				end
			end
			
			4'd8: begin
				hs_ram_data_wr <= 0;
				if (hs_ram_addr == HS_END_ADDR[hs_ram_data_block][19:0]) begin
					if (hs_ram_data_block == HS_NUM) begin
						hs_state <= 4'd0;//idle
					end else begin
						hs_ram_addr <= HS_START_ADDR[hs_ram_data_block+1'd1][19:0];
						hs_ram_data_block <= hs_ram_data_block + 1'd1;
						hs_ram_data_addr <= '0;
						hs_state <= 4'd6;
					end
				end else begin
					hs_ram_addr <= hs_ram_addr + 1'd1;
					hs_ram_data_addr <= hs_ram_data_addr + 8'd1;
					hs_state <= 4'd6;
				end
			end
		endcase
		if (hs_start_cond && !hs_start_cond_old) begin
			hs_state <= 4'd1;
		end
		if ((nvram_upload && !nvram_upload_old) || (reset && !reset_old)) begin
			if (HS_ENABLE && &HS_MATCH[0] && &HS_MATCH[HS_LAST_NUM]) begin
				hs_state <= 4'd5;
				ioctl_wait <= 1;
			end
		end
		
		//load the save data
		hs_load_data_wr <= 0;
		if (nvram_download && !nvram_download_old) begin
			hs_load_data_pos <= 9'h000;
		end
		if (nvram_download && !hs_load_addr[24] && ioctl_wr) begin
			hs_load_data_pos <= hs_load_data_pos + 9'd1;
			if (!HS_LOADED[0]) begin
				hs_load_data_addr <= hs_load_data_pos;
				hs_load_data_wr <= 1;
				if (hs_load_addr[15:0] == (HS_LEN[0] - 1)) begin
					HS_LOADED[0] <= 1;
					hs_load_data_pos <= 9'h100;
				end
			end
			else if (!HS_LOADED[1] && HS_LAST_NUM) begin
				hs_load_data_addr <= hs_load_data_pos;
				hs_load_data_wr <= 1;
				if (hs_load_addr[15:0] == (HS_LEN[1] + HS_LEN[0] - 1)) HS_LOADED[1] <= 1;
			end
		end
		
		if (nvram_upload && !nvram_upload_old) begin
			hs_load_data_pos <= 9'h000;
			HS_UPLOADED <= '{2{1'b0}};
		end
		if (nvram_upload && !hs_load_addr[24] && ioctl_rd) begin
			hs_load_data_pos <= hs_load_data_pos + 9'd1;
			if (!HS_UPLOADED[0]) begin
				hs_load_data_addr <= hs_load_data_pos;
				if (hs_load_addr[15:0] == (HS_LEN[0] - 1)) begin
					HS_UPLOADED[0] <= 1;
					hs_load_data_pos <= 9'h100;
				end
			end
			else if (!HS_UPLOADED[1] && HS_LAST_NUM) begin
				hs_load_data_addr <= hs_load_data_pos;
				if (hs_load_addr[15:0] == (HS_LEN[1] + HS_LEN[0] - 1)) HS_UPLOADED[1] <= 1;
			end
		end
		
		//load config
		hsconf_download_old <= hsconf_download;
		if (hsconf_download && !hsconf_download_old) begin
			HS_ENABLE <= 1'b0;
			HS_LAST_NUM <= 0;
			HS_LOADED <= '{2{1'b0}};
			HS_MATCH <= '{2{2'b00}};
		end
		if (hsconf_download && ioctl_wr) begin
			HS_NUM = ioctl_addr[3:3];
			case (ioctl_addr[2:0])
				3'h0: HS_START_ADDR[HS_NUM][31:24] <= ioctl_data[7:0];
				3'h1: HS_START_ADDR[HS_NUM][23:16] <= ioctl_data[7:0];
				3'h2: HS_START_ADDR[HS_NUM][15: 8] <= ioctl_data[7:0];
				3'h3: HS_START_ADDR[HS_NUM][ 7: 0] <= ioctl_data[7:0];
				3'h4: HS_LEN[HS_NUM][15: 8] <= ioctl_data[7:0];
				3'h5: HS_LEN[HS_NUM][ 7: 0] <= ioctl_data[7:0];
				3'h6: HS_START_DATA[HS_NUM] <= ioctl_data[7:0];
				3'h7: HS_END_DATA[HS_NUM] <= ioctl_data[7:0]; 
			endcase
			if (ioctl_addr[2:0] == 3'h7) begin
				HS_END_ADDR[HS_NUM] <= HS_START_ADDR[HS_NUM] + HS_LEN[HS_NUM] - 32'd1;
				HS_ENABLE <= 1;
				HS_LAST_NUM <= HS_NUM;
			end
		end
		
		DRAM_DO_BYTES = '{DRAM_DO[31:24],DRAM_DO[23:16],DRAM_DO[15: 8],DRAM_DO[ 7: 0]};
		if (!DRAM_CE_N && !(&DRAM_WE_N)) begin
			for (int i=0;i<2;i++) begin
				if (DRAM_A == HS_START_ADDR[i][19:2] && DRAM_WE_N[~HS_START_ADDR[i][1:0]] == 1'b0 && DRAM_DO_BYTES[HS_START_ADDR[i][1:0]] == HS_START_DATA[i]) HS_MATCH[i][0] <= 1;
				if (DRAM_A == HS_END_ADDR[i][19:2]   && DRAM_WE_N[~HS_END_ADDR[i][1:0]]   == 1'b0 && DRAM_DO_BYTES[HS_END_ADDR[i][1:0]]   == HS_END_DATA[i]  ) HS_MATCH[i][1] <= 1;
			end
		end
		if (reset && !reset_old) begin
			HS_MATCH <= '{2{2'b00}};
		end
	end
	wire hs_start_cond = HS_ENABLE && HS_LOADED[0] && &HS_MATCH[0] && HS_LOADED[HS_LAST_NUM] && &HS_MATCH[HS_LAST_NUM];
	
	wire hs_dram_hit0 = (DRAM_A[19:2] >= HS_START_ADDR[0][19:2] && DRAM_A[19:2] <= HS_END_ADDR[0][19:2]);
	wire hs_dram_hit1 = (DRAM_A[19:2] >= HS_START_ADDR[1][19:2] && DRAM_A[19:2] <= HS_END_ADDR[1][19:2]);
	
	wire [ 7: 0] eeprom_q;
	dpram_dif #(8,8,8,8," ") eeprom
	(
		.clock(clk_sys),

		.address_a(EEP_MEM_A),
		.data_a(EEP_MEM_DATA),
		.wren_a(EEP_MEM_WREN),
		.q_a(EEP_MEM_Q),

		.address_b(nvram_download || nvram_upload ? ioctl_addr[7:0] : eeprom_addr),
		.data_b(nvram_download ? ioctl_data : eeprom_data),
		.wren_b(nvram_download ? hs_load_addr[24] & ioctl_wr : eeprom_wr),
		.q_b(eeprom_q)
	);
	
	wire dram_we = ~DRAM_CE_N & ~&DRAM_WE_N;
	reg dram_we_old;	
	reg hs_match_delayed[4];	
	always @(posedge clk_sys) begin
		dram_we_old <= dram_we;
		hs_match_delayed[0] <= HS_ENABLE && &HS_MATCH[0] && &HS_MATCH[HS_LAST_NUM];
		hs_match_delayed[1] <= hs_match_delayed[0];
		hs_match_delayed[2] <= hs_match_delayed[1];
		hs_match_delayed[3] <= hs_match_delayed[2];
	end
	
	wire [ 7: 0] hs_load_q;
	dpram #(9,8) hsbuf
	(
		.clock(clk_sys),

		.address_a({hs_ram_data_block,hs_ram_data_addr}),
		.data_a(hsram_do),
		.wren_a(hs_ram_data_wr),
		.q_a(hs_data_in),

		.address_b(hs_load_data_addr),
		.data_b(ioctl_data),
		.wren_b(hs_load_data_wr),
		.q_b(hs_load_q)
	);

	reg nvram_save_req;	
	always @(posedge clk_sys) begin
		if (reset) begin
			nvram_save_req <= 0;
		end else begin
			if (nvram_upload) begin
				nvram_save_req <= 0;
			end else if (EEP_MEM_WREN || (dram_we && dram_we_old && (hs_dram_hit0 || hs_dram_hit1) && hs_match_delayed[3])) begin
				nvram_save_req <= 1;
			end
		end
	end
	
	assign ioctl_upload_req = (status[16] && nvram_save_req) || status[17];
	assign ioctl_din = (ioctl_index == 8'h04) ? (ioctl_addr < 25'h100 ? eeprom_q : hs_load_q) : 
															  '0;

/////////////////////////  Video  /////////////////////////////
	wire [1:0] ar = status[2:1];
	wire [2:0] scale = status[8:6];
	wire [2:0] sd = status[13:11];
	wire [2:0] sl = sd ? sd - 1'd1 : 3'd0;
	wire       scandoubler = (sd || forced_scandoubler);
	
	wire [1:0] rotate_sel = status[4:3];
	wire       rotate_en  = (rotate_sel != 2'd0 & (ps3_board|ps5_board));
	wire       rotate_ccw = (rotate_sel == 2'd1 & (ps3_board|ps5_board));
	wire       flip_180   = status[5] & (ps3_board|ps5_board);
	reg        two_screen;
	
	assign CLK_VIDEO = clk_sys;
	assign VGA_F1 = 0;
	assign VGA_SL = sl[1:0];

	reg DCE1,DCE2;
	always @(posedge clk_sys) begin
		reg [1:0] DCLK1_old,DCLK2_old;
		reg       VBL_N_old;
		
		DCLK1_old[1] <= DCLK1_old[0];
		DCLK1_old[0] <= DCLK1;
		DCE1 <= ~DCLK1_old[0] & DCLK1_old[1];
		
		DCLK2_old[1] <= DCLK2_old[0];
		DCLK2_old[0] <= DCLK2;
		DCE2 <= ~DCLK2_old[0] & DCLK2_old[1];
		
		VBL_N_old <= ~VBL_N;
		if (!VBL_N && VBL_N_old) two_screen <= status[10] & ps4_board;
	end
	wire ce_pix = (DCE1) | (DCE2 & two_screen);
	
	wire [11:0] orig_arx = (V240 ? (12'd4<<two_screen) : (12'd10<<two_screen));
	wire [11:0] orig_ary = (V240 ? 12'd3               : 12'd7);
	wire [11:0] arx = (!ar) ? (rotate_en ? orig_ary : orig_arx) : (ar - 1'd1);
	wire [11:0] ary = (!ar) ? (rotate_en ? orig_arx : orig_ary) : 12'd0;
	
	wire vga_de;
	video_freak video_freak
	(
		.CLK_VIDEO(CLK_VIDEO),
		.CE_PIXEL(CE_PIXEL),
		.VGA_VS(VGA_VS),
		.HDMI_WIDTH(HDMI_WIDTH),
		.HDMI_HEIGHT(HDMI_HEIGHT),
		.VGA_DE(VGA_DE),
		.VIDEO_ARX(VIDEO_ARX),
		.VIDEO_ARY(VIDEO_ARY),
		.VGA_DE_IN(vga_de),
		.ARX(arx),
		.ARY(ary),
		.CROP_SIZE(12'd0),
		.CROP_OFF(5'd0),
		.SCALE(scale) 
	);
	
	wire [31: 3] fb_addr;
	wire [63: 0] fb_data;
	wire         fb_we;
	wire [ 7: 0] fb_be;
	wire         fb_busy;
	screen_rotate_two screen_rotate_two
	(
		.CLK_VIDEO     (CLK_VIDEO),
		.CE_PIXEL      (ce_pix),

		.VGA_R         (VGA_R),
		.VGA_G         (VGA_G),
		.VGA_B         (VGA_B),
		.VGA_HS        (VGA_HS),
		.VGA_VS        (VGA_VS),
		.VGA_DE        (vga_de),

		.rotate_ccw    (rotate_ccw),
		.no_rotate     (~rotate_en),
		.flip          (flip_180),
		.two_screen    (two_screen),
		.video_rotated (),
		

		.FB_EN         (FB_EN),
		.FB_FORMAT     (FB_FORMAT),
		.FB_WIDTH      (FB_WIDTH),
		.FB_HEIGHT     (FB_HEIGHT),
		.FB_BASE       (FB_BASE),
		.FB_STRIDE     (FB_STRIDE),
		.FB_VBL        (FB_VBL),
		.FB_LL         (FB_LL),
		.FB_FORCE_BLANK(FB_FORCE_BLANK),

		.DDRAM_CLK     (),
		.DDRAM_BUSY    (fb_busy),
		.DDRAM_BURSTCNT(),
		.DDRAM_ADDR    (fb_addr),
		.DDRAM_DIN     (fb_data),
		.DDRAM_BE      (fb_be),
		.DDRAM_WE      (fb_we),
		.DDRAM_RD      ()
	);

	video_mixer #(.LINE_LENGTH(640), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
	(
		.*,
	
		.ce_pix(ce_pix),	
		.scandoubler(scandoubler),
		.hq2x(sd == 3'h1),	
		.freeze_sync(),
	
		.VGA_DE(vga_de),
		.R(R),
		.G(G),
		.B(B),
	
		// Positive pulses.
		.HSync(~HS_N), 
		.VSync(~VS_N),  
		.HBlank(~HBL_N),
		.VBlank(~VBL_N) 
	);

	//debug
	reg  [ 5: 0] SCRN_EN = 6'b111111;
	reg  [ 2: 0] SND_EN = 3'b111;
`ifdef DEBUG
	reg          DBG_PAUSE = 0;
	reg          DBG_BREAK = 0;
	reg          DBG_RUN = 0;
	
	reg  [ 7: 0] DBG_EXT = '0;
	
	wire         pressed = ps2_key[9];
	wire [ 8: 0] code    = ps2_key[8:0];
	always @(posedge clk_sys) begin
		reg old_state = 0, VBL_N_OLD;
		
		VBL_N_OLD <= VBL_N;
		
		if (VBL_N && !VBL_N_OLD) begin
			if (DBG_PAUSE && !DBG_BREAK) DBG_BREAK <= 1;
			else if ((DBG_RUN || !DBG_PAUSE) && DBG_BREAK) DBG_BREAK <= 0;
			DBG_RUN <= 0;
		end
		
		DBG_EXT <= '0;
		
		old_state <= ps2_key[10];
		if((ps2_key[10] != old_state) && pressed) begin
			casex(code)
				'h005: begin SCRN_EN[0] <= ~SCRN_EN[0]; end 	// F1
				'h006: begin SCRN_EN[1] <= ~SCRN_EN[1]; end 	// F2
				'h004: begin SCRN_EN[2] <= ~SCRN_EN[2]; end 	// F3
				'h00C: begin SCRN_EN[3] <= ~SCRN_EN[3]; end 	// F4
				'h003: begin SCRN_EN[4] <= ~SCRN_EN[4]; end 	// F5
				'h00B: begin SCRN_EN[5] <= ~SCRN_EN[5]; end 	// F6
				'h083: begin SND_EN[0] <= ~SND_EN[0]; end 	// F7
				'h00A: begin SND_EN[1] <= ~SND_EN[1]; end 	// F8
				'h001: begin SND_EN[2] <= ~SND_EN[2]; end 	// F9
				'h009: begin SCRN_EN <= '1; SND_EN <= '1; DBG_EXT <= '0; end 	// F10
//				'h078: begin DBG_BREAK <= ~DBG_BREAK; end 	// F11
				'h078: begin DBG_RUN <= 1; end 	// F11
				'h177: begin DBG_PAUSE <= ~DBG_PAUSE; end 	// Pause
			endcase
		end
		
		if(pressed) begin
			casex(code)
				'h016: begin DBG_EXT[0] <= 1; end 	// 1
				'h01E: begin DBG_EXT[1] <= 1; end 	// 2
				'h026: begin DBG_EXT[2] <= 1; end 	// 3
				'h025: begin DBG_EXT[3] <= 1; end 	// 4
				'h02E: begin DBG_EXT[4] <= 1; end 	// 5
				'h036: begin DBG_EXT[5] <= 1; end 	// 6
				'h03D: begin DBG_EXT[6] <= 1; end 	// 7
				'h03E: begin DBG_EXT[7] <= 1; end 	// 8
				default:;
			endcase
		end
	end
`endif

endmodule
