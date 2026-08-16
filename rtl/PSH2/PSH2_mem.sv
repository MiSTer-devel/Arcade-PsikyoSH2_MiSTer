// synopsys translate_off
`define SIM
// synopsys translate_on

module PSH2_SPRITE_RAM
(
	input          CLK,
	input  [15: 1] WRADDR,
	input  [15: 0] DATA,
	input  [ 1: 0] WREN,
	input  [15: 1] RDADDR,
	output [15: 0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [2**15];
	initial begin
		MEM <= '{2**15{'0}};
	end
	always @(posedge CLK) begin
		if (WREN[0]) begin
			MEM[WRADDR][15:8] <= DATA[15:8];
		end
		if (WREN[1]) begin
			MEM[WRADDR][7:0] <= DATA[7:0];
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [15:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (WREN),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
				.address_b (RDADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({16{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**15,
		altsyncram_component.numwords_b = 2**15,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 15,
		altsyncram_component.widthad_b = 15,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 2;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_PAL_RAM
(
	input          CLK,
	input  [13: 2] WRADDR,
	input  [ 7: 0] DATA,
	input          WREN,
	input  [13: 2] RDADDR,
	output [ 7: 0] Q
);

`ifdef SIM
	
	reg [7:0] MEM [2**12];
	initial begin
		MEM <= '{2**12{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [7:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (1'b1),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (WREN),
				.address_b (RDADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({8{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
//		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**12,
		altsyncram_component.numwords_b = 2**12,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 12,
		altsyncram_component.widthad_b = 12,
		altsyncram_component.width_a = 8,
		altsyncram_component.width_b = 8,
		altsyncram_component.width_byteena_a = 1;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_ZOOM_RAM
(
	input          CLK,
	input  [ 7: 0] WRADDR,
	input  [15: 0] DATA,
	input          WREN,
	input  [ 7: 0] RDADDR,
	output [15: 0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [2**8];
	initial begin
		MEM <= '{2**8{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
	end
	assign Q <= MEM[RDADDR];
	
`else

	wire [15:0] sub_wire0;
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.byteena (1'b1),
				.q (sub_wire0),
				.aclr (1'b0),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 16,
		altdpram_component.widthad = 8,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_SPRITE_LIST
 #(parameter wa =10)
(
	input            CLK,
	input  [wa-1: 0] WRADDR,
	input  [  15: 0] DATA,
	input            WREN,
	input  [wa-1: 0] RDADDR,
	output [  15: 0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [2**wa];
	initial begin
		MEM <= '{2**wa{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [15:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (1'b1),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (WREN),
				.address_b (RDADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({16{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
//		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**wa,
		altsyncram_component.numwords_b = 2**wa,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = wa,
		altsyncram_component.widthad_b = wa,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 1;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_SPRITE_PARAM
(
	input          CLK,
	input  [ 8: 0] WRADDR,
	input  [76: 0] DATA,
	input          WREN,
	input  [ 8: 0] RDADDR,
	output [76: 0] Q
);

`ifdef SIM
	
	reg [76:0] MEM [2**10];
	initial begin
		MEM <= '{2**10{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [76:0] sub_wire0;
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.byteena (1'b1),
				.q (sub_wire0),
				.aclr (1'b0),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
//		altdpram_component.byte_size = 8,
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 77,
		altdpram_component.widthad = 9,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_SPRITE_PHASE_Y
(
	input          CLK,
	input  [ 9: 0] WRADDR,
	input  [ 9: 0] DATA,
	input          WREN,
	input  [ 9: 0] RDADDR,
	output [ 9: 0] Q
);

`ifdef SIM
	
	reg [9:0] MEM [2**10];
	initial begin
		MEM <= '{2**10{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [9:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (1'b1),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (WREN),
				.address_b (RDADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({10{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
//		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**10,
		altsyncram_component.numwords_b = 2**10,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 10,
		altsyncram_component.widthad_b = 10,
		altsyncram_component.width_a = 10,
		altsyncram_component.width_b = 10,
		altsyncram_component.width_byteena_a = 1;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule


module PSH2_SPRITE_OFFS_X
(
	input          CLK,
	input  [ 8: 0] WRADDR,
	input  [19: 0] DATA,
	input          WREN,
	input  [ 8: 0] RDADDR,
	output [19: 0] Q
);

`ifdef SIM
	
	reg [19:0] MEM [2**9];
	initial begin
		MEM <= '{2**9{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
	end
	assign Q = MEM[RDADDR];
	
`else

	wire [19:0] sub_wire0;
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.byteena (1'b1),
				.q (sub_wire0),
				.aclr (1'b0),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
//		altdpram_component.byte_size = 8,
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 20,
		altdpram_component.widthad = 9,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_SPRITE_LIST_Y
 #(parameter wa =10)
(
	input            CLK,
	input  [wa-1: 0] WRADDR,
	input  [  13: 0] DATA,
	input            WREN,
	input  [wa-1: 0] RDADDR,
	output [  13: 0] Q
);

`ifdef SIM
	
	reg [13:0] MEM [2**wa];
	initial begin
		MEM <= '{2**wa{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [13:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (1'b1),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (WREN),
				.address_b (RDADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({14{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
//		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**wa,
		altsyncram_component.numwords_b = 2**wa,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = wa,
		altsyncram_component.widthad_b = wa,
		altsyncram_component.width_a = 14,
		altsyncram_component.width_b = 14,
		altsyncram_component.width_byteena_a = 1;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_SPREVAL_LIST
(
	input          CLK,
	input  [ 8: 0] WRADDR,
	input  [ 9: 0] DATA,
	input          WREN,
	input  [ 8: 0] RDADDR,
	output [ 9: 0] Q
);

`ifdef SIM
	
	reg [9:0] MEM [2**9];
	initial begin
		MEM <= '{2**9{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
	end
	assign Q = MEM[RDADDR];
	
`else

	wire [9:0] sub_wire0;
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.byteena (1'b1),
				.q (sub_wire0),
				.aclr (1'b0),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
//		altdpram_component.byte_size = 8,
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 10,
		altdpram_component.widthad = 9,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;
	
`endif
	
endmodule

module PSH2_SPR_LINE
(
	input          CLK,
	input  [ 8: 0] WRADDR,
	input  [20: 0] DATA,
	input          WREN,
	input  [ 8: 0] RDADDR,
	output [20: 0] Q
);

`ifdef SIM
	
	reg [20:0] MEM [2**9];
	initial begin
		MEM <= '{2**9{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
	end
	assign Q = MEM[RDADDR];
	
`else

	wire [20:0] sub_wire0;
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.byteena (1'b1),
				.q (sub_wire0),
				.aclr (1'b0),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
//		altdpram_component.byte_size = 8,
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 21,
		altdpram_component.widthad = 9,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;
	
`endif
	
endmodule
