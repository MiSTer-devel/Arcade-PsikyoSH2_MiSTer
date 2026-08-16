module PSH2 
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE,
	
	input              RES_N,
	
	output     [20: 1] ROM_A,
	input      [31: 0] ROM_D,
	output             PROM_CE_N,
	output             DROM_CE_N,
	output             ROM_OE_N,
	
	output     [19: 2] DRAM_A,
	input      [31: 0] DRAM_DI,
	output     [31: 0] DRAM_DO,
	output     [ 3: 0] DRAM_WE_N,
	output             DRAM_RD_N,
	output             DRAM_CE_N,
	
	input              MEM_WAIT_N,
	
	output     [24: 0] GFX_ROM_A,
	input      [31: 0] GFX_ROM_D,
	output             GFX_ROM_RD_N,
	
	output     [22: 0] SOUND_ROM_A,
	input      [ 7: 0] SOUND_ROM_D,
	output             SOUND_ROM_RD_N,
	
	output     [ 7: 0] EEP_MEM_A,
	input      [ 7: 0] EEP_MEM_Q,
	output             EEP_MEM_WREN,
	output     [ 7: 0] EEP_MEM_DATA,
	
	output     [ 7: 0] R,
	output     [ 7: 0] G,
	output     [ 7: 0] B,
	output             DCLK1,
	output             DCLK2,
	output             HS_N,
	output             VS_N,
	output             HBL_N,
	output             VBL_N,
	output             V240,
	
	output     [15: 0] SOUND_L,
	output     [15: 0] SOUND_R,
	
	input      [ 7: 0] P0,
	input      [ 7: 0] P1,
	input      [ 7: 0] P2,
	input      [ 7: 0] P3,
	input      [ 7: 0] P4,
	input      [ 7: 0] P5,
	input      [ 7: 0] P6,
	input      [ 7: 0] P7,
	output reg [ 7: 0] PA_O,
	input      [ 7: 0] JP4,
	
	input      [ 1: 0] VER,		//0-PS3,1-PS5,2-PS4
	
	input      [ 5: 0] SCRN_EN,
	input      [ 8: 0] HS_OFFS,
	input      [ 2: 0] SND_EN,
	input              SND_MONO
	
`ifdef DEBUG
                      ,
	input              DBG_PAUSE,
	output reg [15: 0] DBG_CLKDIV
`endif
);


	bit  [26: 0] CPU_A;
	bit  [31: 0] CPU_DI;
	bit  [31: 0] CPU_DO;
	bit  [ 3: 0] CPU_WE_N;
	bit          CPU_RD_N;
	bit          CPU_RD_WR_N;
	bit          CPU_CS0_N;
	bit          CPU_CS1_N;
	bit          CPU_CS2_N;
	bit          CPU_CS3_N;

	bit  [15: 0] PS_DO;
	bit          PS_CS_N;
	bit          PS_WAIT_N;
	bit          PS_IRQ_N;
	bit  [14: 0] PS_SRAM_A;
	bit  [15: 0] PS_SRAM_DI;
	bit  [15: 0] PS_SRAM_DO;
	bit          PS_SRAM_OE_N;
	bit  [ 1: 0] PS_SRAM_WE_N;
	bit          PS_SRAM_CE_N;
	bit  [21: 0] PS_ROM_A;
	bit  [ 5: 0] PS_ROM_CE_N;
	bit          PS_ROM_OE_N;
	bit  [ 7: 0] EEP_IN;
	bit  [ 7: 0] PS35_EEP_DATA,PS4_EEP_DATA;
	
	bit  [ 7: 0] YMF_DO;
	bit          YMF_CS_N;
	bit          YMF_RES_N;
	bit          YMF_IRQ_N;
	bit  [20: 0] YMF_MA;
	bit  [ 9: 0] YMF_MCS_N;
	bit  [15: 0] PS4_YMF_BANK;
	
	bit  [ 7: 0] IO_DO;
	bit          IO_CS_N;
	
	wire         PROG_SEL = (!CPU_CS0_N && CPU_A[24:20] == 5'b00000);
	wire         DATA_SEL = (!CPU_CS1_N && CPU_A[24:20] == 5'b00000 && VER == 2'h0) || (!CPU_CS2_N && CPU_A[24:20] == 5'b10000 && VER == 2'h1) || (!CPU_CS1_N && CPU_A[24:21] == 4'b0000  && VER == 2'h2);
	wire         PS_SEL   = (!CPU_CS1_N && CPU_A[24:20] == 5'b10000 && VER == 2'h0) || (!CPU_CS2_N && CPU_A[24:20] == 5'b00000 && VER == 2'h1) || (!CPU_CS1_N && CPU_A[24:20] == 5'b10000 && VER == 2'h2);
	wire         YMF_SEL  = (!CPU_CS2_N && CPU_A[24:20] == 5'b10000 && VER == 2'h0) || (!CPU_CS1_N && CPU_A[24:20] == 5'b10001 && VER == 2'h1) || (!CPU_CS2_N && CPU_A[24:20] == 5'b10000 && VER == 2'h2);
	wire         IO_SEL   = (!CPU_CS2_N && CPU_A[24:20] == 5'b11000 && VER == 2'h0) || (!CPU_CS1_N && CPU_A[24:20] == 5'b10000 && VER == 2'h1) || (!CPU_CS2_N && CPU_A[24:20] == 5'b11000 && VER == 2'h2);
	
	assign PS_CS_N = ~PS_SEL;
	assign YMF_CS_N = ~YMF_SEL;
	assign IO_CS_N = ~IO_SEL;
	
	bit CLK_DIV;
	always @(posedge CLK) CLK_DIV <= ~CLK_DIV;
	wire SYS_CE_R =  CLK_DIV;
	wire SYS_CE_F = ~CLK_DIV;
	
	SH7604 #(.UBC_DISABLE(1), .SCI_DISABLE(1), .BUS_AREA_TIMIMG({1'b1,3'b111}), .BUS_SIZE_BYTE_DISABLE(0)) CPU
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(SYS_CE_R),
		.CE_F(SYS_CE_F),
`ifdef DEBUG
		.EN(EN & ~DBG_PAUSE),
`else
		.EN(EN),
`endif
		
		.RES_N(RES_N),
		.NMI_N(1'b1),
		
		.IRL_N({YMF_IRQ_N,PS_IRQ_N&YMF_IRQ_N,2'b11}),
		
		.A(CPU_A),
		.DI(CPU_DI),
		.DO(CPU_DO),
		.BS_N(),
		.CS0_N(CPU_CS0_N),
		.CS1_N(CPU_CS1_N),
		.CS2_N(CPU_CS2_N),
		.CS3_N(CPU_CS3_N),
		.RD_WR_N(CPU_RD_WR_N),
		.WE_N(CPU_WE_N),
		.RD_N(CPU_RD_N),
		.IVECF_N(),
		.RFS(),
		
		.EA('0),
		.EDI(),
		.EDO('0),
		.EBS_N(1'b1),
		.ECS0_N(1'b1),
		.ECS1_N(1'b1),
		.ECS2_N(1'b1),
		.ECS3_N(1'b1),
		.ERD_WR_N(1'b1),
		.EWE_N('1),
		.ERD_N(1'b1),
		.ECE_N(1'b1),
		.EOE_N(1'b1),
		.EIVECF_N(1'b1),
		
		.WAIT_N(PS_WAIT_N & MEM_WAIT_N),
		.IVECF_N(),
		.BRLS_N(1'b1),
		.BGR_N(),
		
		.DREQ0(1'b1),
		.DREQ1(1'b1),
		
		.FTCI(1'b1),
		.FTI(1'b1),
		
		.RXD(1'b1),
		.TXD(),
		.SCKO(),
		.SCKI(1'b1),
		
		.MD(6'b010110),
		
		.FAST(1'b0)
		
`ifdef DEBUG
		,
		.DBG_REGN('0),
		.DBG_REGQ(),
		.DBG_RUN(1),
		.DBG_BREAK()
`endif
	);
	assign CPU_DI = !PROM_CE_N || !DROM_CE_N ? ROM_D : 
	                !CPU_CS3_N ? DRAM_DI : 
						 !PS_CS_N ? {16'h0000,PS_DO} :
	                !YMF_CS_N ? {24'h000000,YMF_DO} :
						 !IO_CS_N ? {24'h000000,IO_DO} :
						 32'h00000000;
	
	assign ROM_A = CPU_A[20:1];
	assign PROM_CE_N = ~PROG_SEL;
	assign DROM_CE_N = ~DATA_SEL;
	assign ROM_OE_N = CPU_RD_N;
	
	assign DRAM_A = CPU_A[19:2];
	assign DRAM_DO = CPU_DO;
	assign DRAM_WE_N = CPU_WE_N;
	assign DRAM_RD_N = CPU_RD_N;
	assign DRAM_CE_N = CPU_CS3_N;
	
	
	bit  [15: 0] PS6406B_DO;
	bit          PS6406B_WAIT_N;
	bit          PS6406B_IRQ_N;
	bit  [21: 0] PS6406B_ROM_A;
	bit  [ 5: 0] PS6406B_ROM_CE_N;
	bit          PS6406B_ROM_OE_N;
	bit  [14: 0] PS6406B_SRAM_A;
	bit  [15: 0] PS6406B_SRAM_DO;
//	bit          PS6406B_SRAM_OE_N;
	bit  [ 1: 0] PS6406B_SRAM_WE_N;
	bit          PS6406B_SRAM_CE_N;
	bit  [ 7: 0] PS6406B_R;
	bit  [ 7: 0] PS6406B_G;
	bit  [ 7: 0] PS6406B_B;
	bit          PS6406B_DCLK;
	bit          PS6406B_HS_N;
	bit          PS6406B_VS_N;
	bit          PS6406B_HBL_N;
	bit          PS6406B_VBL_N;
	bit          PS6406B_V240;
	PS6406B PS6406B
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE(SYS_CE_R),
		
		.A(CPU_A[18:1]),
		.DI(CPU_DO[15:0]),
		.DO(PS6406B_DO),
		.RD_N(CPU_RD_N),
		.WE_N(CPU_WE_N[1:0]),
		.CS_N(PS_CS_N),
		.WAIT_N(PS6406B_WAIT_N),
		
		.IRQ_N(PS6406B_IRQ_N),
		
		.ROM_A(PS6406B_ROM_A),
		.ROM_D(GFX_ROM_D),
		.ROM_CE_N(PS6406B_ROM_CE_N),
		.ROM_OE_N(PS6406B_ROM_OE_N),
		
		.SRAM_A(PS6406B_SRAM_A),
		.SRAM_DI(PS_SRAM_DI),
		.SRAM_DO(PS6406B_SRAM_DO),
		.SRAM_OE_N(),
		.SRAM_WE_N(PS6406B_SRAM_WE_N),
		.SRAM_CE_N(PS6406B_SRAM_CE_N),
		
		.R(PS6406B_R),
		.G(PS6406B_G),
		.B(PS6406B_B),
		.DCLK(PS6406B_DCLK),
		.HS_N(PS6406B_HS_N),
		.VS_N(PS6406B_VS_N),
		.HBL_N(PS6406B_HBL_N),
		.VBL_N(PS6406B_VBL_N),
		.V240(PS6406B_V240),
		
		.SCRN_EN(SCRN_EN),
		.HS_OFFS(HS_OFFS)
	);
	
	bit  [15: 0] PS6807_DO;
	bit          PS6807_WAIT_N;
	bit          PS6807_IRQ_N;
	bit  [21: 0] PS6807_ROM_A;
	bit  [ 5: 0] PS6807_ROM_CE_N;
	bit          PS6807_ROM_OE_N;
	bit  [14: 0] PS6807_SRAM_A;
	bit  [15: 0] PS6807_SRAM_DO;
//	bit          PS6807_SRAM_OE_N;
	bit  [ 1: 0] PS6807_SRAM_WE_N;
	bit          PS6807_SRAM_CE_N;
	bit  [ 7: 0] PS6807_R;
	bit  [ 7: 0] PS6807_G;
	bit  [ 7: 0] PS6807_B;
	bit          PS6807_DCLK1,PS6807_DCLK2;
	bit          PS6807_HS_N;
	bit          PS6807_VS_N;
	bit          PS6807_HBL_N;
	bit          PS6807_VBL_N;
	bit          PS6807_V240;
	PS6807 PS6807
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE(SYS_CE_R),
		
		.A(CPU_A[14:1]),
		.DI(CPU_DO[15:0]),
		.DO(PS6807_DO),
		.RD_N(CPU_RD_N),
		.WE_N(CPU_WE_N[1:0]),
		.CS_N(PS_CS_N),
		.WAIT_N(PS6807_WAIT_N),
		
		.IRQ_N(PS6807_IRQ_N),
		
		.ROM_A(PS6807_ROM_A),
		.ROM_D(GFX_ROM_D),
		.ROM_CE_N(PS6807_ROM_CE_N),
		.ROM_OE_N(PS6807_ROM_OE_N),
		
		.SRAM_A(PS6807_SRAM_A),
		.SRAM_DI(PS_SRAM_DI),
		.SRAM_DO(PS6807_SRAM_DO),
		.SRAM_OE_N(),
		.SRAM_WE_N(PS6807_SRAM_WE_N),
		.SRAM_CE_N(PS6807_SRAM_CE_N),
		
		.R(PS6807_R),
		.G(PS6807_G),
		.B(PS6807_B),
		.DCLK1(PS6807_DCLK1),
		.DCLK2(PS6807_DCLK2),
		.HS_N(PS6807_HS_N),
		.VS_N(PS6807_VS_N),
		.HBL_N(PS6807_HBL_N),
		.VBL_N(PS6807_VBL_N),
		.V240(PS6807_V240),
		
		.EEP_OUT(PS4_EEP_DATA),
		.EEP_IN(EEP_IN),
		
		.SCRN_EN(SCRN_EN),
		.HS_OFFS(HS_OFFS)
	);
	
	always_comb begin
		if (VER <= 2'h1) begin
			{PS_DO,PS_WAIT_N,PS_IRQ_N} = {PS6406B_DO,PS6406B_WAIT_N,PS6406B_IRQ_N};
			{PS_ROM_A,PS_ROM_CE_N,PS_ROM_OE_N} = {PS6406B_ROM_A,PS6406B_ROM_CE_N,PS6406B_ROM_OE_N};
			{PS_SRAM_A,PS_SRAM_DO,PS_SRAM_WE_N,PS_SRAM_CE_N} = {PS6406B_SRAM_A,PS6406B_SRAM_DO,PS6406B_SRAM_WE_N,PS6406B_SRAM_CE_N};
			{R,G,B} = {PS6406B_R,PS6406B_G,PS6406B_B};
			{DCLK1,DCLK2,HS_N,VS_N,HBL_N,VBL_N,V240} = {PS6406B_DCLK,1'b0,PS6406B_HS_N,PS6406B_VS_N,PS6406B_HBL_N,PS6406B_VBL_N,PS6406B_V240};
		end
		else begin
			{PS_DO,PS_WAIT_N,PS_IRQ_N} = {PS6807_DO,PS6807_WAIT_N,PS6807_IRQ_N};
			{PS_ROM_A,PS_ROM_CE_N,PS_ROM_OE_N} = {PS6807_ROM_A,PS6807_ROM_CE_N,PS6807_ROM_OE_N};
			{PS_SRAM_A,PS_SRAM_DO,PS_SRAM_WE_N,PS_SRAM_CE_N} = {PS6807_SRAM_A,PS6807_SRAM_DO,PS6807_SRAM_WE_N,PS6807_SRAM_CE_N};
			{R,G,B} = {PS6807_R,PS6807_G,PS6807_B};
			{DCLK1,DCLK2,HS_N,VS_N,HBL_N,VBL_N,V240} = {PS6807_DCLK1,PS6807_DCLK2,PS6807_HS_N,PS6807_VS_N,PS6807_HBL_N,PS6807_VBL_N,PS6807_V240};
		end
	end
	
	assign GFX_ROM_A = {!PS_ROM_CE_N[0]?3'b000:
	                     !PS_ROM_CE_N[1]?3'b001:
								!PS_ROM_CE_N[2]?3'b010:
								!PS_ROM_CE_N[3]?3'b011:
								!PS_ROM_CE_N[4]?3'b100:3'b101,PS_ROM_A};
	assign GFX_ROM_RD_N = PS_ROM_OE_N;
	
	PSH2_SPRITE_RAM SPRITE_RAM
	(
		.CLK(CLK),
		.WRADDR(PS_SRAM_A),
		.DATA(PS_SRAM_DO),
		.WREN(~PS_SRAM_WE_N & ~{2{PS_SRAM_CE_N}}),
		.RDADDR(PS_SRAM_A),
		.Q(PS_SRAM_DI)
	);
	
	YMF278B YMF278B
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE(SYS_CE_R),
		
		.A(CPU_A[2:0]),
		.DI(CPU_DO[7:0]),
		.DO(YMF_DO),
		.RD_N(CPU_RD_N),
		.WR_N(CPU_WE_N[0]),
		.CS_N(YMF_CS_N),
		.IC_N(YMF_RES_N),
	
		.IRQ_N(YMF_IRQ_N),
		
		.MA(YMF_MA),
		.MDI(SOUND_ROM_D),
		.MDO(),
		.MRD_N(SOUND_ROM_RD_N),
		.MWR_N(),
		.MCS_N(YMF_MCS_N),
	
		.OUT1_L(SOUND_L),
		.OUT1_R(SOUND_R),
		
		.SND_EN(SND_EN),
		.MONO(SND_MONO)
	);
	
	always_comb begin
		bit [ 2: 0] YMF_BANK[4];
		
		YMF_BANK = '{PS4_YMF_BANK[2:0],PS4_YMF_BANK[6:4],PS4_YMF_BANK[10:8],PS4_YMF_BANK[14:12]};
		if (VER <= 2'h1) begin
			SOUND_ROM_A = {1'b0,YMF_MCS_N[0],YMF_MA};
		end else begin
			SOUND_ROM_A = !YMF_MCS_N[2] ? {YMF_BANK[0],YMF_MA[19:0]} :
			              !YMF_MCS_N[3] ? {YMF_BANK[1],YMF_MA[19:0]} :
							  !YMF_MCS_N[4] ? {YMF_BANK[2],YMF_MA[19:0]} :
							  !YMF_MCS_N[5] ? {YMF_BANK[3],YMF_MA[19:0]} : '0;
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit          CPU_WE0_N_OLD;
		
		if (!RST_N) begin
			PS35_EEP_DATA <= '1;
			PS4_YMF_BANK <= '0;
			PA_O <= '0;
		end else if (EN) begin
			if (SYS_CE_R) begin
				CPU_WE0_N_OLD <= CPU_WE_N[0];
				if (IO_SEL && !CPU_WE_N[0] && CPU_WE0_N_OLD) begin
					case (CPU_A[3:0])
						4'h4: PS35_EEP_DATA <= CPU_DO[7:0];
						4'h8: PS4_YMF_BANK[15:8] <= CPU_DO[7:0];
						4'h9: PS4_YMF_BANK[7:0] <= CPU_DO[7:0];
						4'hA: PA_O <= CPU_DO[7:0];
						default:;
					endcase
				end
				
			end
		end
	end
	
	bit          EEP_DI,EEP_DO,EEP_CS,EEP_CLK;
	always_comb begin
		if (VER <= 2'h1) begin
			{EEP_CS,EEP_CLK,EEP_DI} <= PS35_EEP_DATA[7:5];
			YMF_RES_N <= PS35_EEP_DATA[1];
		end else begin
			{EEP_CS,EEP_CLK,EEP_DI} <= PS4_EEP_DATA[7:5];
			YMF_RES_N <= RST_N;
		end
	end
	assign EEP_IN = {EEP_CS,EEP_CLK,EEP_DI,EEP_DO,JP4[3:0]};
	
	always_comb begin
		if (VER <= 2'h1) begin
			case (CPU_A[2:0])
				3'h0: IO_DO <= P0;
				3'h1: IO_DO <= P1;
				3'h2: IO_DO <= P2;
				3'h3: IO_DO <= P3;
				3'h4: IO_DO <= EEP_IN;
				default: IO_DO <= '1;
			endcase
		end else begin
			case (CPU_A[2:0])
				3'h0: IO_DO <= P0;
				3'h1: IO_DO <= P1;
				3'h2: IO_DO <= P2;
				3'h3: IO_DO <= P3;
				3'h4: IO_DO <= P4;
				3'h5: IO_DO <= P5;
				3'h6: IO_DO <= P6;
				3'h7: IO_DO <= P7;
				default: IO_DO <= '1;
			endcase
		end
	end
	
	E93C56A EEP
	(
		.CLK(CLK),
		.RST_N(RST_N),
		
		.DI(EEP_DI),
		.DO(EEP_DO),
		.CS(EEP_CS),
		.SK(EEP_CLK),
		
		.MEM_A(EEP_MEM_A),
		.MEM_Q(EEP_MEM_Q),
		.MEM_WREN(EEP_MEM_WREN),
		.MEM_DATA(EEP_MEM_DATA)
	);
	
`ifdef DEBUG
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DBG_CLKDIV <= 0;
		end else if (EN) begin
			if (CE) begin
				DBG_CLKDIV <= DBG_CLKDIV + 1'd1;
			end
		end
	end
`endif

endmodule
