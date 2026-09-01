//============================================================================
//  Copyright (C) 2023 Martin Donlon
//
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
//
//  Derived from Arcade-IremM92_MiSTer.
//  Changes from the source version:
//  - expose keyboard state as generic arcade switch inputs
//  - use a cabinet/player arcade switch layout
//  - add cabinet test/coin and player service mappings
//  - fix coin slot 4 mapping
//  - name PS/2 scancodes and switch positions for readability
//
//  Top-level integration:
//  - add rtl/arcade_switches_pkg.sv before this file in the project file
//  - import ARCADE_SWITCHES_PKG::* where the switch bits are consumed
//  - connect ps2_key from hps_io and clock this module with the same clk_sys
//    used by hps_io; ps2_key is a decoded event bus
//  - map cabinet_sw and p*_sw into the core's local input ports
//
//  Parameters:
//  - PS2_KEY_WIDTH is the hps_io ps2_key bus width. MiSTer hps_io uses 11 bits:
//    {event toggle, pressed, extended, code[7:0]}.
//  - PLAYERS limits which player switch outputs respond to keyboard events.
//  - PUSH_SWITCHES limits how many push switches per player respond. Direction,
//    start, service, cabinet test, coin, and pause are not counted as switches.
//  - PLAYER_SW_WIDTH is derived from PUSH_SWITCHES and P_SW_PUSH_BASE.
//
//  Switch outputs are active high: a bit is 1 while the switch/key is pressed.
//============================================================================

module mame_keyboard_switches #(
	parameter integer PS2_KEY_WIDTH       = 11,
	parameter integer PLAYERS             = 4,
	parameter integer PUSH_SWITCHES       = 6,
	parameter integer PLAYER_SW_WIDTH     = ARCADE_SWITCHES_PKG::P_SW_PUSH_BASE + PUSH_SWITCHES
) (
	input clk,
	input reset,

	input [PS2_KEY_WIDTH-1:0] ps2_key,

	output ARCADE_SWITCHES_PKG::cabinet_sw_t cabinet_sw,
	output reg [PLAYER_SW_WIDTH-1:0] p1_sw,
	output reg [PLAYER_SW_WIDTH-1:0] p2_sw,
	output reg [PLAYER_SW_WIDTH-1:0] p3_sw,
	output reg [PLAYER_SW_WIDTH-1:0] p4_sw,

	output reg pause
);

import ARCADE_SWITCHES_PKG::*;

reg old_state;

localparam
	PS2_CODE_MSB = 8,
	PS2_PRESSED  = 9,
	PS2_EVENT    = 10;

// MAME default arcade keyboard layout:
// P1: arrows, left Ctrl/Alt, Space, left Shift
//     Z/X for push switches 5-6
// P2: R/F/D/G, A/S/Q/W/E/K
// P3: I/K/J/L, right Ctrl/Shift, Enter
// P4: keypad 8/2/4/6, keypad 0/Period/Enter
// Start: 1/2/3/4, Coin: 5/6/7/8, P1/P2 Service: 9/0, Test: F2, Pause: P
localparam [8:0]
	SC_1          = 9'h016,
	SC_2          = 9'h01e,
	SC_3          = 9'h026,
	SC_4          = 9'h025,
	SC_5          = 9'h02e,
	SC_6          = 9'h036,
	SC_7          = 9'h03d,
	SC_8          = 9'h03e,
	SC_9          = 9'h046,
	SC_0          = 9'h045,
	SC_F2         = 9'h006,
	SC_UP         = 9'h175,
	SC_DOWN       = 9'h172,
	SC_LEFT       = 9'h16b,
	SC_RIGHT      = 9'h174,
	SC_CTRL       = 9'h014,
	SC_ALT        = 9'h011,
	SC_SPACE      = 9'h029,
	SC_SHIFT      = 9'h012,
	SC_Z          = 9'h01a,
	SC_X          = 9'h022,
	SC_R          = 9'h02d,
	SC_F          = 9'h02b,
	SC_D          = 9'h023,
	SC_G          = 9'h034,
	SC_A          = 9'h01c,
	SC_S          = 9'h01b,
	SC_Q          = 9'h015,
	SC_W          = 9'h01d,
	SC_E          = 9'h024,
	SC_I          = 9'h043,
	SC_K          = 9'h042,
	SC_J          = 9'h03b,
	SC_L          = 9'h04b,
	SC_RCTRL      = 9'h114,
	SC_RSHIFT     = 9'h059,
	SC_ENTER      = 9'h05a,
	SC_NUM_8      = 9'h075,
	SC_NUM_2      = 9'h072,
	SC_NUM_4      = 9'h06b,
	SC_NUM_6      = 9'h074,
	SC_NUM_0      = 9'h070,
	SC_NUM_PERIOD = 9'h071,
	SC_NUM_ENTER  = 9'h15a,
	SC_P          = 9'h04d;

function automatic bit player_enabled;
	input integer player_number;
begin
	player_enabled = player_number <= PLAYERS;
end
endfunction

function automatic [PLAYER_SW_WIDTH-1:0] set_player_sw;
	input [PLAYER_SW_WIDTH-1:0] player_sw;
	input integer bit_index;
	input bit value;
begin
	set_player_sw = player_sw;
	if (bit_index >= 0 && bit_index < PLAYER_SW_WIDTH) set_player_sw[bit_index] = value;
end
endfunction

function automatic [PLAYER_SW_WIDTH-1:0] set_player_push_sw;
	input [PLAYER_SW_WIDTH-1:0] player_sw;
	input integer push_sw;
	input bit value;
	integer push_number;
begin
	set_player_push_sw = player_sw;
	push_number = push_sw - P_SW_PUSH_BASE + 1;
	if (push_sw >= P_SW_PUSH_BASE && push_sw < PLAYER_SW_WIDTH && push_number <= PUSH_SWITCHES) begin
		set_player_push_sw = set_player_sw(player_sw, push_sw, value);
	end
end
endfunction

always_ff @(posedge clk) begin
	bit p;

	if (reset) begin
		cabinet_sw <= '0;
		p1_sw <= '0;
		p2_sw <= '0;
		p3_sw <= '0;
		p4_sw <= '0;

		pause <= 0;
		old_state <= ps2_key[PS2_EVENT];
	end else begin
		p = ps2_key[PS2_PRESSED];

		old_state <= ps2_key[PS2_EVENT];
		if (old_state != ps2_key[PS2_EVENT]) begin
			case (ps2_key[PS2_CODE_MSB:0])
				SC_1: if (player_enabled(1)) p1_sw <= set_player_sw(p1_sw, P_SW_START, p);
				SC_2: if (player_enabled(2)) p2_sw <= set_player_sw(p2_sw, P_SW_START, p);
				SC_3: if (player_enabled(3)) p3_sw <= set_player_sw(p3_sw, P_SW_START, p);
				SC_4: if (player_enabled(4)) p4_sw <= set_player_sw(p4_sw, P_SW_START, p);

				SC_5: cabinet_sw[C_SW_COIN1] <= p;
				SC_6: cabinet_sw[C_SW_COIN2] <= p;
				SC_7: cabinet_sw[C_SW_COIN3] <= p;
				SC_8: cabinet_sw[C_SW_COIN4] <= p;
				SC_9: if (player_enabled(1)) p1_sw <= set_player_sw(p1_sw, P_SW_SERVICE, p);
				SC_0: if (player_enabled(2)) p2_sw <= set_player_sw(p2_sw, P_SW_SERVICE, p);
				SC_F2: cabinet_sw[C_SW_TEST] <= p;

				SC_UP:    if (player_enabled(1)) p1_sw <= set_player_sw(p1_sw, P_SW_UP, p);
				SC_DOWN:  if (player_enabled(1)) p1_sw <= set_player_sw(p1_sw, P_SW_DOWN, p);
				SC_LEFT:  if (player_enabled(1)) p1_sw <= set_player_sw(p1_sw, P_SW_LEFT, p);
				SC_RIGHT: if (player_enabled(1)) p1_sw <= set_player_sw(p1_sw, P_SW_RIGHT, p);
				SC_CTRL:  if (player_enabled(1)) p1_sw <= set_player_push_sw(p1_sw, P_SW_PUSH1, p);
				SC_ALT:   if (player_enabled(1)) p1_sw <= set_player_push_sw(p1_sw, P_SW_PUSH2, p);
				SC_SPACE: if (player_enabled(1)) p1_sw <= set_player_push_sw(p1_sw, P_SW_PUSH3, p);
				SC_SHIFT: if (player_enabled(1)) p1_sw <= set_player_push_sw(p1_sw, P_SW_PUSH4, p);
				SC_Z:     if (player_enabled(1)) p1_sw <= set_player_push_sw(p1_sw, P_SW_PUSH5, p);
				SC_X:     if (player_enabled(1)) p1_sw <= set_player_push_sw(p1_sw, P_SW_PUSH6, p);

				SC_R: if (player_enabled(2)) p2_sw <= set_player_sw(p2_sw, P_SW_UP, p);
				SC_F: if (player_enabled(2)) p2_sw <= set_player_sw(p2_sw, P_SW_DOWN, p);
				SC_D: if (player_enabled(2)) p2_sw <= set_player_sw(p2_sw, P_SW_LEFT, p);
				SC_G: if (player_enabled(2)) p2_sw <= set_player_sw(p2_sw, P_SW_RIGHT, p);
				SC_A: if (player_enabled(2)) p2_sw <= set_player_push_sw(p2_sw, P_SW_PUSH1, p);
				SC_S: if (player_enabled(2)) p2_sw <= set_player_push_sw(p2_sw, P_SW_PUSH2, p);
				SC_Q: if (player_enabled(2)) p2_sw <= set_player_push_sw(p2_sw, P_SW_PUSH3, p);
				SC_W: if (player_enabled(2)) p2_sw <= set_player_push_sw(p2_sw, P_SW_PUSH4, p);
				SC_E: if (player_enabled(2)) p2_sw <= set_player_push_sw(p2_sw, P_SW_PUSH5, p);

				SC_I: if (player_enabled(3)) p3_sw <= set_player_sw(p3_sw, P_SW_UP, p);
				SC_K: begin
					if (player_enabled(2)) p2_sw <= set_player_push_sw(p2_sw, P_SW_PUSH6, p);
					if (player_enabled(3)) p3_sw <= set_player_sw(p3_sw, P_SW_DOWN, p);
				end
				SC_J:      if (player_enabled(3)) p3_sw <= set_player_sw(p3_sw, P_SW_LEFT, p);
				SC_L:      if (player_enabled(3)) p3_sw <= set_player_sw(p3_sw, P_SW_RIGHT, p);
				SC_RCTRL:  if (player_enabled(3)) p3_sw <= set_player_push_sw(p3_sw, P_SW_PUSH1, p);
				SC_RSHIFT: if (player_enabled(3)) p3_sw <= set_player_push_sw(p3_sw, P_SW_PUSH2, p);
				SC_ENTER:  if (player_enabled(3)) p3_sw <= set_player_push_sw(p3_sw, P_SW_PUSH3, p);

				SC_NUM_8:      if (player_enabled(4)) p4_sw <= set_player_sw(p4_sw, P_SW_UP, p);
				SC_NUM_2:      if (player_enabled(4)) p4_sw <= set_player_sw(p4_sw, P_SW_DOWN, p);
				SC_NUM_4:      if (player_enabled(4)) p4_sw <= set_player_sw(p4_sw, P_SW_LEFT, p);
				SC_NUM_6:      if (player_enabled(4)) p4_sw <= set_player_sw(p4_sw, P_SW_RIGHT, p);
				SC_NUM_0:      if (player_enabled(4)) p4_sw <= set_player_push_sw(p4_sw, P_SW_PUSH1, p);
				SC_NUM_PERIOD: if (player_enabled(4)) p4_sw <= set_player_push_sw(p4_sw, P_SW_PUSH2, p);
				SC_NUM_ENTER:  if (player_enabled(4)) p4_sw <= set_player_push_sw(p4_sw, P_SW_PUSH3, p);

				SC_P: pause <= p;
			endcase
		end
	end
end

endmodule
