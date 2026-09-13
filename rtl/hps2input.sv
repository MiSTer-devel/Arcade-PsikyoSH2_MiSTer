module HPS2INPUT 
(
	input              clk,
	input              reset,
	
	input      [31: 0] joystick_0,
	input      [31: 0] joystick_1,
	input      [31: 0] joystick_2,
   input      [31: 0] joystick_3,
   input      [10: 0] ps2_key,

   input      [ 7: 0] BOARD_CONF,
   input      [ 7: 0] dip_sw,
	
	output     [ 7: 0] p0,
	output     [ 7: 0] p1,
	output     [ 7: 0] p2,
	output     [ 7: 0] p3,
	output     [ 7: 0] p4,
	output     [ 7: 0] p5,
	output     [ 7: 0] p6,
	output     [ 7: 0] p7,
	input      [ 7: 0] pA_o,
   output             key_pause
);

	import ARCADE_SWITCHES_PKG::*;

	localparam [2:0] INPUT_1_PUSH_SWITCH = 3'h0;
	localparam [2:0] INPUT_2_PUSH_SWITCH = 3'h1;
	localparam [2:0] INPUT_3_PUSH_SWITCH = 3'h2;
	localparam [2:0] INPUT_4_PUSH_SWITCH = 3'h3;
	localparam [2:0] INPUT_MAHJONG       = 3'h4;
	localparam PCB_PLAYERS       = 4;
	localparam PCB_PUSH_SWITCHES = 4;
	localparam PCB_PLAYER_SW_WIDTH = P_SW_PUSH_BASE + PCB_PUSH_SWITCHES;

	cabinet_sw_t key_cabinet_sw;
	wire [PCB_PLAYER_SW_WIDTH-1:0] key_p1_sw,key_p2_sw,key_p3_sw,key_p4_sw;
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
		.clk(clk),
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

		if (BOARD_CONF[1:0] <= 2'h1) begin	//PS3/PS5
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
	
endmodule
