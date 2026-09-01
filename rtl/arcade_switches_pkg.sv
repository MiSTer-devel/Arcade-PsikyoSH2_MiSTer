//============================================================================
//  Common arcade switch state definitions.
//
//  These types use logical active-high state: a bit is 1 when the switch is
//  on/closed. Actual arcade cabinet switch wiring is commonly active low with
//  pullups, so top-level adapters should invert as needed when packing these
//  states into a PCB's input ports.
//
//  cabinet_sw_t holds switches that belong to the cabinet rather than an
//  individual player, such as test, tilt, and coin switches.
//
//  Player switch constants describe one player's digital switch state.
//  Directional lever switches, start, service, and push switches are named
//  here so top-level adapters can pack them into each core's native input
//  ports without relying on raw bit numbers at call sites.
//
//  This package intentionally does not define a fixed-width player switch
//  type. A core should size its player switch vectors from the number of push
//  switches it supports:
//
//    localparam PLAYER_SW_WIDTH = P_SW_PUSH_BASE + PUSH_SWITCHES;
//============================================================================

package ARCADE_SWITCHES_PKG;

localparam C_SW_WIDTH = 8;
typedef bit [C_SW_WIDTH-1:0] cabinet_sw_t;

// Cabinet switch byte. Test and tilt use the upper bits; coin switches use
// the lower bits so the full keyboard state has a single compact output.
localparam
	C_SW_TEST  = 7,
	C_SW_TILT1 = 6,
	C_SW_TILT2 = 5,
	C_SW_TILT3 = 4,
	C_SW_COIN1 = 3,
	C_SW_COIN2 = 2,
	C_SW_COIN3 = 1,
	C_SW_COIN4 = 0;

// Player switch state follows the common source-table order, while keeping
// push switches expandable from P_SW_PUSH_BASE.
localparam
	P_SW_START     = 0,
	P_SW_SERVICE   = 1,
	P_SW_UP        = 2,
	P_SW_DOWN      = 3,
	P_SW_LEFT      = 4,
	P_SW_RIGHT     = 5,
	P_SW_PUSH_BASE = 6,
	P_SW_PUSH1     = P_SW_PUSH_BASE + 0,
	P_SW_PUSH2     = P_SW_PUSH_BASE + 1,
	P_SW_PUSH3     = P_SW_PUSH_BASE + 2,
	P_SW_PUSH4     = P_SW_PUSH_BASE + 3,
	P_SW_PUSH5     = P_SW_PUSH_BASE + 4,
	P_SW_PUSH6     = P_SW_PUSH_BASE + 5,
	P_SW_PUSH7     = P_SW_PUSH_BASE + 6,
	P_SW_PUSH8     = P_SW_PUSH_BASE + 7;

endpackage
