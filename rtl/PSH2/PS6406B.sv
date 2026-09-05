// synopsys translate_off
`define SIM
// synopsys translate_on

module PS6406B 
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE,
	
	input      [18: 1] A,
	input      [15: 0] DI,
	output     [15: 0] DO,
	input              RD_N,
	input      [ 1: 0] WE_N,
	input              CS_N,
	output             WAIT_N,
	
	output             IRQ_N,
	
	output     [21: 0] ROM_A,
	input      [31: 0] ROM_D,
	output     [ 5: 0] ROM_CE_N,
	output             ROM_OE_N,
	
	output     [14: 0] SRAM_A,
	input      [15: 0] SRAM_DI,
	output     [15: 0] SRAM_DO,
	output             SRAM_OE_N,
	output     [ 1: 0] SRAM_WE_N,
	output             SRAM_CE_N,
	
	output     [ 7: 0] R,
	output     [ 7: 0] G,
	output     [ 7: 0] B,
	output             DCLK,
	output             HS_N,
	output             VS_N,
	output             HBL_N,
	output             VBL_N,
	output             V240,
	
	input      [ 5: 0] SCRN_EN,
	input      [ 8: 0] HS_OFFS
	
`ifdef DEBUG
	                   ,
	output     [31: 0] DBG_REGS,
	output     [15: 0] DBG_BG_ADDR,DBG_SPR_ADDR,
	output     [26: 0] DBG_ROM_ADDR,
	output SpriteFetch_t DBG_SPR_LIST,
	
	output reg [26: 0] DBG_ROM_ADDR2,
	output reg [ 8: 0] DBG_BG_ROM_X2,
	output reg [31: 0] DBG_BG_FETCH_DATA2
`endif
);

	import PS6406B_PKG::*;
	
	bit  [31: 0] REGS[8];
	REG0_t       REG0;
	REG1_t       REG1;
	REG2_t       REG2;
	REG6_t       REG6;
	REG7_t       REG7;
	bit  [15: 0] IACK;
	bit          VINT_PEND,VINT_REQ;
	
	bit          DOT_CE_R,DOT_CE_F;
	bit          RENDER_SRAM_CYCLE;
	bit          RENDER_ROM_CYCLE;
	bit          BG_FETCH_EN;
	bit  [24: 0] ROM_ADDR;
	
	wire         IACK_SEL = (A >= (19'h53FDC>>1) && A <= (19'h53FDD>>1) && !CS_N) || (A >= (19'h5FFDC>>1) && A <= (19'h5FFDD>>1) && !CS_N);
	wire         REG_SEL  = (A >= (19'h53FE0>>1) && A <= (19'h53FFF>>1) && !CS_N) || (A >= (19'h5FFE0>>1) && A <= (19'h5FFFF>>1) && !CS_N);
	wire         IO_SPRRAM_SEL = (A >= (19'h00000>>1) && A <= (19'h0FFFF>>1) && !CS_N);
	wire         PALETTE_SEL = (A >= (19'h40000>>1) && A <= (19'h43FFF>>1) && !CS_N);
	wire         ZOOMRAM_SEL = (A >= (19'h50000>>1) && A <= (19'h501FF>>1) && !CS_N);
	wire         IO_GFX_SEL = (A >= (19'h60000>>1) && A <= (19'h7FFFF>>1) && !CS_N);
	
	bit          WE_N_OLD;
	always @(posedge CLK or negedge RST_N) begin
		bit          VINT_PEND_OLD;
		
		if (!RST_N) begin
			REGS <= '{8{'0}};
			IACK <= '0;
		end else if (EN) begin
			if (CE) begin
				WE_N_OLD <= &WE_N;
				if (REG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!A[1] && !WE_N[1]) REGS[A[4:2]][31:24] <= DI[15: 8];
					if (!A[1] && !WE_N[0]) REGS[A[4:2]][23:16] <= DI[ 7: 0];
					if ( A[1] && !WE_N[1]) REGS[A[4:2]][15: 8] <= DI[15: 8];
					if ( A[1] && !WE_N[0]) REGS[A[4:2]][ 7: 0] <= DI[ 7: 0];
				end
				
				VINT_PEND_OLD <= VINT_PEND;
				if (VINT_PEND && !VINT_PEND_OLD) begin
					VINT_REQ <= 1;
				end
				if (IACK[0] && SPR_LOAD_RUN) begin
					IACK[0] <= 0;
				end
				if (IACK_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!WE_N[1]) IACK[15: 8] <= DI[15: 8];
					if (!WE_N[0]) IACK[ 7: 0] <= DI[ 7: 0];
					if (!WE_N[0] && DI[7:6] == 2'b00) VINT_REQ <= 0;
				end
			end
		end
	end
	assign DO = IACK_SEL ? IACK : 
	            REG_SEL ? (!A[1] ? REGS[A[4:2]][31:16] : REGS[A[4:2]][15:0]) : 
					IO_SPRRAM_SEL ? IO_SRAM_DO : 
	            PALETTE_SEL ? (!A[1] ? PAL_Q[23:8] : {PAL_Q[7:0],8'h00}) : 
					ZOOMRAM_SEL ? IO_ZOOM_RAM_Q : 
					IO_GFX_SEL ? IO_ROM_DO : 
					'0;
	assign WAIT_N = ~(IO_SPRRAM_SEL & IO_SPRRAM_WAIT) & ~(IO_GFX_SEL & IO_ROM_WAIT);
	
	assign IRQ_N = ~VINT_REQ;
	
	assign {REG0,REG1,REG2,REG6,REG7} = {REGS[0],REGS[1],REGS[2],REGS[6],REGS[7]};
	
	//Sprite RAM
	bit  [15: 0] IO_SRAM_DO;
	bit          IO_SPRRAM_WAIT;
	bit          IO_SPRRAM_CYCLE;
	always @(posedge CLK or negedge RST_N) begin
		bit          SPRRAM_SEL_OLD;
		
		if (!RST_N) begin
			IO_SPRRAM_WAIT <= 0;
			IO_SPRRAM_CYCLE <= 0;
		end else if (EN) begin
			SPRRAM_SEL_OLD <= IO_SPRRAM_SEL;
			if (IO_SPRRAM_SEL && !SPRRAM_SEL_OLD) begin
				IO_SPRRAM_WAIT <= 1;
			end
			if (CE) begin
				IO_SPRRAM_CYCLE <= IO_SPRRAM_WAIT;
				if (IO_SPRRAM_CYCLE && !RENDER_SRAM_CYCLE) begin
					IO_SRAM_DO <= SRAM_DI;
					IO_SPRRAM_CYCLE <= 0;
					IO_SPRRAM_WAIT <= 0;
				end
			end
		end
	end
	assign SRAM_A = RENDER_SRAM_CYCLE ? (!BG_RENDER_ACTIVE ? SPR_ADDR : BG_ADDR) : IO_SPRRAM_CYCLE ? A[15:1] : '0;
	assign SRAM_DO = DI;
	assign SRAM_OE_N = RENDER_SRAM_CYCLE ? 1'b0 : IO_SPRRAM_CYCLE ? RD_N : 1'b1;
	assign SRAM_WE_N = RENDER_SRAM_CYCLE ? 2'b11 : IO_SPRRAM_CYCLE ? WE_N : 2'b11;
	assign SRAM_CE_N = ~(RENDER_SRAM_CYCLE | IO_SPRRAM_CYCLE);
	
	//Palette
	wire [11: 0] PAL_RA = PALETTE_SEL && !RD_N ? A[13:2] : BG_COLOR;
	wire         PAL_WE = PALETTE_SEL & ~(&WE_N) & WE_N_OLD;
	bit  [23: 0] PAL_Q;
	PSH2_PAL_RAM PALR(CLK, A[13:2], DI[15: 8], PAL_WE & ~A[1] & ~WE_N[1] & CE, PAL_RA, PAL_Q[23:16]);
	PSH2_PAL_RAM PALG(CLK, A[13:2], DI[ 7: 0], PAL_WE & ~A[1] & ~WE_N[0] & CE, PAL_RA, PAL_Q[15: 8]);
	PSH2_PAL_RAM PALB(CLK, A[13:2], DI[15: 8], PAL_WE &  A[1] & ~WE_N[1] & CE, PAL_RA, PAL_Q[ 7: 0]);
	
	//Zoom RAM
	bit  [ 7: 0] SPR_EVAL_ZOOMX,SPR_EVAL_ZOOMY;
	
	wire         ZOOM_RAM_WE = ZOOMRAM_SEL & ~(&WE_N) & WE_N_OLD;
	wire [ 7: 0] ZOOM_RAM_X_RA = SPR_EVAL_ZOOMX;
	wire [ 7: 0] ZOOM_RAM_Y_RA = SPR_LOAD_RUN ? SPR_LOAD_ZOOMY : SPR_EVAL_ZOOMY;
	bit  [15: 0] IO_ZOOM_RAM_Q,ZOOM_RAM_X_Q,ZOOM_RAM_Y_Q;
	PSH2_ZOOM_RAM IO_ZOOM_RAM(CLK, A[8:1], DI, ZOOM_RAM_WE & CE, A[8:1], IO_ZOOM_RAM_Q);
	PSH2_ZOOM_RAM ZOOM_RAM_X (CLK, A[8:1], DI, ZOOM_RAM_WE & CE, ZOOM_RAM_X_RA, ZOOM_RAM_X_Q);
	PSH2_ZOOM_RAM ZOOM_RAM_Y (CLK, A[8:1], DI, ZOOM_RAM_WE & CE, ZOOM_RAM_Y_RA, ZOOM_RAM_Y_Q);
	
	//ROM
	bit  [15: 0] IO_ROM_DO;
	bit          IO_ROM_WAIT;
	bit          IO_ROM_CYCLE;
	always @(posedge CLK or negedge RST_N) begin
		bit          IO_GFX_SEL_OLD;
		
		if (!RST_N) begin
			IO_ROM_WAIT <= 0;
			IO_ROM_CYCLE <= 0;
		end else if (EN) begin
			IO_GFX_SEL_OLD <= IO_GFX_SEL;
			if (IO_GFX_SEL && !IO_GFX_SEL_OLD) begin
				IO_ROM_WAIT <= 1;
			end
			if (DOT_CE_R) begin
				IO_ROM_CYCLE <= IO_ROM_WAIT;
				if (IO_ROM_CYCLE && !RENDER_ROM_CYCLE) begin
					IO_ROM_DO <= A[1] ? {ROM_D[23:16],ROM_D[31:24]} : {ROM_D[7:0],ROM_D[15:8]};
					IO_ROM_CYCLE <= 0;
					IO_ROM_WAIT <= 0;
				end
			end
		end
	end
	
	wire [24:0] TEMP_ROM_A = RENDER_ROM_CYCLE ? ROM_ADDR[24:0] : {REGS[4][9:0],A[16:2]};
	assign ROM_A = TEMP_ROM_A[21:0];
	assign ROM_CE_N = !TEMP_ROM_A[24] ? (!TEMP_ROM_A[23] ? (!TEMP_ROM_A[22] ? 6'b111110 : 6'b111101) : 
	                                                       (!TEMP_ROM_A[22] ? 6'b111011 : 6'b110111)) : 
												   (!TEMP_ROM_A[23] ? (!TEMP_ROM_A[22] ? 6'b101111 : 6'b011111) : 
	                                                       (!TEMP_ROM_A[22] ? 6'b111111 : 6'b111111));
	assign ROM_OE_N = ~(RENDER_ROM_CYCLE | IO_ROM_CYCLE);
	
	//Video generator
	bit          CLK_RES;
	always @(posedge CLK) begin
		bit          RST_N_OLD;
	
		if (CE) begin
			RST_N_OLD <= RST_N;
			CLK_RES <= RST_N & ~RST_N_OLD;
		end
	end
	
	bit  [ 1: 0] DOTCLK_DIV;
	always @(posedge CLK) begin
		if (CLK_RES) begin
			DOTCLK_DIV <= '0;
		end else if (CE) begin
			DOTCLK_DIV <= DOTCLK_DIV + 2'd1;
		end
	end
	assign DOT_CE_R = (DOTCLK_DIV == 3) & CE;
	
	wire [ 8: 0] DOT_BREAK = (REGS[3][7] == 1'b1 ? 9'd443 : 9'd456) - 9'd8;
	// Original hardware uses 262 total lines and a four-line VSYNC in both modes.
	wire [ 8: 0] LINE_BREAK = 9'h0FF;
	wire [ 8: 0] HSYNC_START = 9'h168 + HS_OFFS;
	wire [ 8: 0] VBLK_START = REGS[3][7] == 1'b1 ? 9'h0F0 : 9'h0E0;
	wire [ 8: 0] VSYNC_START = REGS[3][7] == 1'b1 ? 9'd244 : 9'd236;
	wire [ 8: 0] VSYNC_WIDTH = 9'd4;
	bit  [ 8: 0] HCNT;
	bit  [ 8: 0] VCNT;
	bit          HSYNC;
	bit          VSYNC;
	bit          HBLK;
	bit          VBLK;
	always @(posedge CLK) begin		
		if (CLK_RES) begin
			HCNT <= '0;
			VCNT <= '0;
			HSYNC <= 1;
			VSYNC <= 1;
			HBLK <= 0;
			VBLK <= 0;
			VINT_PEND <= 0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				VINT_PEND <= 0;
				HCNT <= HCNT + 9'd1;
				if (HCNT == DOT_BREAK - 1) begin
					HCNT <= 9'h1F8;
				end
				if (HCNT == 9'h1FF) begin
					VCNT <= VCNT + 9'd1;
					if (VCNT == LINE_BREAK) begin
						VCNT <= 9'h1FA;
					end
					
					if (VCNT == VBLK_START - 9'd1) begin
						VBLK <= 1;
					end
					if (VCNT == 9'h1FF) begin
						VBLK <= 0;
					end
				end
				if (HCNT == 9'h162 - 1 && VCNT == VBLK_START) begin
					VINT_PEND <= 1;
				end
				
				if (HCNT == 9'h1FF && VCNT == VSYNC_START - 9'd1) begin
					VSYNC <= 1;
				end
				if (HCNT == 9'h1FF && VCNT == VSYNC_START + VSYNC_WIDTH - 9'd1) begin
					VSYNC <= 0;
				end
				
				if (HCNT == HSYNC_START - 9'h1) begin
					HSYNC <= 1;
				end
				if (HCNT == HSYNC_START + 9'd32 - 9'h1) begin
					HSYNC <= 0;
				end
				
				if (HCNT == 9'd320 - 1) begin
					HBLK <= 1;
				end
				if (HCNT == 9'h1FF) begin
					HBLK <= 0;
				end
			end
		end
	end
	assign DCLK = DOTCLK_DIV[1];
	assign HS_N = ~HSYNC;
	assign VS_N = ~VSYNC;
	assign HBL_N = ~HBLK;
	assign VBL_N = ~VBLK;
	assign V240 = (REGS[3][7] == 1'b1);
	
	/***************Sprites***************/
	bit  [ 3: 0] SPR_PRIO[4];
	bit  [ 7: 0] SPR_ALPHA[8];
	assign SPR_PRIO = '{REG2.S0PRI,REG2.S1PRI,REG2.S2PRI,REG2.S3PRI};
	assign SPR_ALPHA = '{REG0.ALPHA0,REG0.ALPHA1,REG0.ALPHA2,REG0.ALPHA3,REG1.ALPHA4,REG1.ALPHA5,REG1.ALPHA6,REG1.ALPHA7};
	
	//Sprites load
	bit          SPR_LOAD_RUN;
	bit  [15: 1] SPR_LIST_ADDR,SPR_LOAD_ADDR;
	bit  [ 9: 0] SPR_LIST_NUM;
	bit  [ 2: 0] SPR_LOAD_STATE;
	
	bit  [15: 0] SPR_NUM;
	bit  [23: 0] SPR_LOAD_OFFSY;
	bit  [ 7: 0] SPR_LOAD_ZOOMY;
	always @(posedge CLK or negedge RST_N) begin	
		bit          SPR_LOAD_PEND,SPR_LOAD_PEND2;	
		bit          IACK0_OLD;	
		bit  [ 9: 0] SPR_Y;
		bit  [15: 0] SPR_ZOOMY_VAL;
		
		if (!RST_N) begin
			SPR_LIST_NUM <= '0;
			SPR_LOAD_STATE <= '0;
			SPR_LOAD_RUN <= 0;
			SPR_NUM <= '0;
			{SPR_LOAD_PEND,SPR_LOAD_PEND2} <= '0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				if (HCNT == 9'h1FF && VCNT == VBLK_START - 9'd1 && !SPR_LOAD_PEND) begin
					SPR_LOAD_PEND2 <= 1;
				end
			end
			
			if (CE) begin
				IACK0_OLD <= IACK[0];
				if (IACK[0] && !IACK0_OLD) begin
					SPR_LOAD_PEND <= 1;
				end

				if ((SPR_LOAD_PEND || SPR_LOAD_PEND2) && VBLK) begin
					SPR_LIST_NUM <= '0;
					SPR_LOAD_STATE <= '0;
					SPR_LOAD_RUN <= 1;
					SPR_LOAD_PEND <= 0;
					SPR_LOAD_PEND2 <= 0;
				end
				
				if (SPR_LOAD_RUN) begin
					SPR_LOAD_STATE <= SPR_LOAD_STATE + 3'd1;
					if (SPR_LOAD_STATE == 3'h0) begin
						SPR_NUM <= SRAM_DI;
					end
					if (SPR_LOAD_STATE == 3'h7) begin
						if (SPR_LIST_NUM == 10'h3FF || SPR_NUM[14]) begin
							SPR_LOAD_RUN <= 0;
						end else begin
							SPR_LIST_NUM <= SPR_LIST_NUM + 10'd1;
						end
					end
					
					if (SPR_LOAD_STATE == 3'h0+1) begin
						SPR_Y <= SRAM_DI[9:0];
					end
					if (SPR_LOAD_STATE == 3'h2+1) begin
						SPR_LOAD_ZOOMY <= SRAM_DI[7:0];
					end
					if (SPR_LOAD_STATE == 3'h3+1) begin
						SPR_ZOOMY_VAL <= ZOOM_RAM_Y_Q;
					end
					if (SPR_LOAD_STATE == 3'h4+1) begin
						SPR_LOAD_OFFSY <= (10'h000 - $signed(SPR_Y)) * $unsigned(SPR_ZOOMY_VAL);
					end
				end
			end
		end
	end
	
	bit  [15: 1] SPR_ADDR;
	always_comb begin
		if (SPR_LOAD_STATE == 3'h0)
			SPR_ADDR <= {5'h07,SPR_LIST_NUM};
		else
			SPR_ADDR <= {2'b00,SPR_NUM[9:0],SPR_LOAD_STATE-3'h1};
	end
	
	//Sprites eval
	bit          SPR_EVAL_RUN;
	bit  [ 9: 0] SPR_EVAL_SPRNUM;
	bit  [ 8: 0] SPR_EVAL_CNT;
	bit  [ 7: 0] SPR_EVAL_QUANTITY[2];
	bit          SPR_EVAL_HIT;
	bit  [ 7: 0] SPR_EVAL_VCNT;
	always @(posedge CLK or negedge RST_N) begin	
		bit          SPR_START_OLD;	
		
		if (!RST_N) begin
			SPR_EVAL_RUN <= 0;
			SPR_EVAL_SPRNUM <= '0;
			SPR_EVAL_CNT <= '0;
			SPR_EVAL_QUANTITY <= '{2{'0}};
		end else if (EN) begin
			if (DOT_CE_R) begin
				if (HCNT == 9'h165 && (VCNT >= 9'h1FD || VCNT <= VBLK_START - 9'd2)) begin
					SPR_EVAL_SPRNUM <= '0;
					SPR_EVAL_CNT <= '0;
					SPR_EVAL_RUN <= 1;
					SPR_EVAL_VCNT <= VCNT[7:0] + 8'd3;
				end
			end
			if (CE) begin
				if (SPR_EVAL_RUN) begin
					if (SPR_EVAL_HIT) begin
						SPR_EVAL_CNT <= SPR_EVAL_CNT + 9'd1;
						SPR_EVAL_QUANTITY[SPR_EVAL_VCNT[0]] <= SPR_EVAL_CNT[7:0];
					end
					
					if (SPR_EVAL_SPRNUM == SPR_LIST_NUM || (SPR_EVAL_HIT && SPR_EVAL_CNT == 9'h0FF)) begin
						SPR_EVAL_RUN <= 0;
					end else begin
						SPR_EVAL_SPRNUM <= SPR_EVAL_SPRNUM + 10'd1;
					end
				end
			end
		end
	end
	
	wire [15: 0] SPR_NEW_Y_DATA = {4'h0,SPR_EVAL_PHASE_Y_Q} + ZOOM_RAM_Y_Q;
	
	wire [ 9: 0] SPR_LIST_Y_WA = SPR_LOAD_RUN ? SPR_LIST_NUM : SPR_EVAL_SPRNUM;
	wire         SPR_LIST_Y_WE = (SPR_LOAD_RUN && SPR_LOAD_STATE == 3'h5+1) || SPR_EVAL_RUN;
	wire [ 9: 0] SPR_PHASE_Y_DATA = SPR_LOAD_RUN ? SPR_LOAD_OFFSY[9:0] : SPR_NEW_Y_DATA[9:0];
	bit  [ 9: 0] SPR_EVAL_PHASE_Y_Q;
	PSH2_SPRITE_PHASE_Y SPR_EVAL_PHASE_Y (CLK, SPR_LIST_Y_WA, SPR_PHASE_Y_DATA, SPR_LIST_Y_WE & CE, SPR_EVAL_SPRNUM, SPR_EVAL_PHASE_Y_Q);
	
	wire [13: 0] SPR_LIST_Y_DATA = SPR_LOAD_RUN ? SPR_LOAD_OFFSY[23:10] : SPR_EVAL_LIST_Y_Q + {8'h00,SPR_NEW_Y_DATA[15:10]};
	bit  [13: 0] SPR_EVAL_LIST_Y_Q;
	PSH2_SPRITE_LIST_Y SPR_EVAL_LIST_Y (CLK, SPR_LIST_Y_WA, SPR_LIST_Y_DATA, SPR_LIST_Y_WE & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST_Y_Q);
	
	Sprite_t SPR_EVAL_LIST;
	PSH2_SPRITE_LIST SPR_EVAL_LIST0(CLK, SPR_LIST_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h0+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[95:80]);
	PSH2_SPRITE_LIST SPR_EVAL_LIST1(CLK, SPR_LIST_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h1+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[79:64]);
	PSH2_SPRITE_LIST SPR_EVAL_LIST2(CLK, SPR_LIST_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h2+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[63:48]);
	PSH2_SPRITE_LIST SPR_EVAL_LIST3(CLK, SPR_LIST_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h3+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[47:32]);
	PSH2_SPRITE_LIST SPR_EVAL_LIST4(CLK, SPR_LIST_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h4+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[31:16]);
	PSH2_SPRITE_LIST SPR_EVAL_LIST5(CLK, SPR_LIST_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h5+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[15: 0]);
	assign SPR_EVAL_ZOOMY = SPR_EVAL_LIST.ZOOMY;
	assign SPR_EVAL_ZOOMX = SPR_EVAL_LIST.ZOOMX;
	
	always_comb begin
		bit  [13: 0] SPR_OFFSY;
		bit  [ 3: 0] SPR_H;
		
		SPR_OFFSY = SPR_EVAL_LIST_Y_Q;
		SPR_H = SPR_EVAL_LIST.H;
		
		SPR_EVAL_HIT <= 0;
		if (SPR_OFFSY[13:8] == 6'b000000 && SPR_OFFSY[7:0] <= {SPR_H,4'b1111}) SPR_EVAL_HIT <= 1;
	end
	
	//Sprite fetch
	//Cycle0
	//Y(8), H(4), FLIPY(1), X(10), W(4), FLIPX(1), ZOOMX(16), BPP(1), PAL(8), PRI(2), A(3), TN(19)
	wire [76: 0] SPRITE_PARAM_DATA = {SPR_EVAL_LIST_Y_Q[7:0],SPR_EVAL_LIST.H,SPR_EVAL_LIST.FLIPY,SPR_EVAL_LIST.X,SPR_EVAL_LIST.W,SPR_EVAL_LIST.FLIPX,ZOOM_RAM_X_Q,SPR_EVAL_LIST.BPP,SPR_EVAL_LIST.PAL,SPR_EVAL_LIST.PRI,SPR_EVAL_LIST.A,SPR_EVAL_LIST.TN};
	SpriteFetch_t SPR_LIST;
	PSH2_SPRITE_PARAM SPRITE_PARAM(CLK, {SPR_EVAL_VCNT[0],SPR_EVAL_CNT[7:0]}, SPRITE_PARAM_DATA, SPR_EVAL_RUN & SPR_EVAL_HIT & CE, {SPR_FETCH_LINE,SPR_FETCH_CNT}, SPR_LIST);
	
	bit          SPR_FETCH_LINE;
	bit          SPR_FETCH_RUN;
	bit  [ 7: 0] SPR_FETCH_CNT;
	bit  [ 3: 0] SPR_FETCH_TILE_X,SPR_FETCH_DOT_X;
	bit  [ 7: 0] SPR_FETCH_PAL1;
	bit  [ 2: 0] SPR_FETCH_A1;
	bit  [ 1: 0] SPR_FETCH_PRI1;
	bit          SPR_FETCH_FLIPX1;
	bit          SPR_FETCH_BPP1;
	bit  [19: 0] SPR_FETCH_X;
	
	bit  [15: 0] SPR_FETCH_X1,SPR_FETCH_X1_PREV;
	bit  [15: 0] SPR_FETCH_XINC1;
	bit  [ 2: 0] SPR_DRAW_DOT_NUM1;
	bit  [ 9: 0] SPR_DRAW_X1;
	bit          SPR_DRAW_FIRST1;
	bit          SPR_DRAW_LINE1;
	bit          SPR_LINE_FILL1;
	always @(posedge CLK or negedge RST_N) begin		
		bit  [ 3: 0] NEW_TILE_X,NEW_DOT_X;
		bit  [ 9: 0] SPR_FETCH_X_FRAC,NEW_X_FRAC;
		bit          NEW_TILE_X_OVF;
		bit  [ 7: 0] FETCH_X_MASK;
		bit          FETCH_NEXT_WORD;
		bit  [ 2: 0] DRAW_DOT_NUM;
		bit  [ 9: 0] SPR_X,DRAW_X;
		bit          DRAW_FIRST;
		bit  [ 3: 0] NEW_DRAW_TILE_X,NEW_DRAW_DOT_X;
		bit          NEW_DRAW_TILE_X_OVF;
		bit          DOT_CE2;
		
		if (!RST_N) begin
			SPR_FETCH_RUN <= 0;
			SPR_FETCH_CNT <= '0;
			SPR_LINE_FILL1 <= 0;
		end else if (EN) begin
			FETCH_X_MASK = SPR_LIST.BPP ? 8'hFC : 8'hF8;
			
			{NEW_TILE_X_OVF,NEW_TILE_X,NEW_DOT_X,NEW_X_FRAC} = {1'b0,SPR_FETCH_TILE_X,SPR_FETCH_DOT_X,SPR_FETCH_X_FRAC} + SPR_LIST.ZOOMX;
			FETCH_NEXT_WORD = ({SPR_FETCH_TILE_X,SPR_FETCH_DOT_X} & FETCH_X_MASK) != ({NEW_TILE_X,NEW_DOT_X} & FETCH_X_MASK);
			if (!BG_FETCH_EN) begin
				if (SPR_FETCH_RUN) begin
					if (!FETCH_NEXT_WORD || DOT_CE_R) begin
						{SPR_FETCH_TILE_X,SPR_FETCH_DOT_X,SPR_FETCH_X_FRAC} <= {NEW_TILE_X,NEW_DOT_X,NEW_X_FRAC};
						DRAW_DOT_NUM <= DRAW_DOT_NUM + 3'd1;
						SPR_X <= SPR_X + 10'd1;
					end
				end
			end
			
			DRAW_X = SPR_LIST.X + SPR_X;
			if (DOT_CE_R) begin
				SPR_LINE_FILL1 <= 0;
				if (!BG_FETCH_EN) begin
					DRAW_FIRST <= 0;
					if (SPR_FETCH_RUN) begin
						if ((FETCH_NEXT_WORD && {NEW_TILE_X_OVF,NEW_TILE_X} > {1'b0,SPR_LIST.W}) || (FETCH_NEXT_WORD && !DRAW_X[9] && DRAW_X[8:0] >= 9'h140)) begin
							{SPR_FETCH_TILE_X,SPR_FETCH_DOT_X,SPR_FETCH_X_FRAC} <= 18'h00200;
							SPR_X <= '0;
							DRAW_FIRST <= 1;
							SPR_FETCH_CNT <= SPR_FETCH_CNT + 8'd1;
							if (SPR_FETCH_CNT == SPR_EVAL_QUANTITY[SPR_FETCH_LINE]) begin
								SPR_FETCH_RUN <= 0;
								SPR_FETCH_CNT <= '1;
							end
						end
						SPR_LINE_FILL1 <= 1;
					end
					SPR_FETCH_PAL1 <= SPR_LIST.PAL;
					SPR_FETCH_A1 <= SPR_LIST.A;
					SPR_FETCH_PRI1 <= SPR_LIST.PRI;
					SPR_FETCH_BPP1 <= SPR_LIST.BPP;
					SPR_FETCH_FLIPX1 <= SPR_LIST.FLIPX;
					SPR_FETCH_X1 <= SPR_FETCH_X[15:0];
					SPR_FETCH_XINC1 <= SPR_LIST.ZOOMX;
					SPR_DRAW_DOT_NUM1 <= DRAW_DOT_NUM;
					SPR_DRAW_X1 <= SPR_LIST.X;
					SPR_DRAW_FIRST1 <= DRAW_FIRST;
					SPR_DRAW_LINE1 <= SPR_FETCH_LINE;
				end
				
				DRAW_DOT_NUM <= '0;
				if (HCNT == 9'h165 && (VCNT >= 9'h1FE || VCNT <= VBLK_START - 9'd1)) begin
					SPR_FETCH_LINE = VCNT[0];
					SPR_FETCH_CNT <= '0;
					{SPR_FETCH_TILE_X,SPR_FETCH_DOT_X,SPR_FETCH_X_FRAC} <= 18'h00200;
					SPR_X <= '0;
					DRAW_FIRST <= 1;
					SPR_FETCH_RUN <= (SPR_EVAL_CNT != 9'd0);
				end
			end
			if (DOT_CE2) begin
				SPR_FETCH_X <= {SPR_FETCH_TILE_X,SPR_FETCH_DOT_X,SPR_FETCH_X_FRAC};
			end
			DOT_CE2 <= DOT_CE_R;
		end
	end
		
	bit  [24: 0] SPR_ROM_ADDR;
	always @(posedge CLK or negedge RST_N) begin		
		bit  [ 7: 0] OFFS_Y;
		bit  [ 3: 0] TILE_X,TILE_Y;
		bit  [ 3: 0] DOT_X,DOT_Y;
		bit  [ 7: 0] TILE_OFFS;
		bit  [18: 0] TILE_N;
		
		if (!RST_N) begin
			SPR_ROM_ADDR <= '0;
		end else if (EN) begin
			if (SPR_LIST.FLIPX) DOT_X = ~SPR_FETCH_DOT_X;
			else                DOT_X =  SPR_FETCH_DOT_X;
			if (SPR_LIST.FLIPX) TILE_X = SPR_LIST.W - SPR_FETCH_TILE_X;
			else                TILE_X =              SPR_FETCH_TILE_X;
			
			OFFS_Y = SPR_LIST.Y;
			if (SPR_LIST.FLIPY) DOT_Y = ~OFFS_Y[3:0];
			else                DOT_Y =  OFFS_Y[3:0];
			if (SPR_LIST.FLIPY) TILE_Y = SPR_LIST.H - OFFS_Y[7:4];
			else                TILE_Y =              OFFS_Y[7:4];
			
			TILE_OFFS = (TILE_Y * SPR_LIST.W) + {4'b0000,TILE_Y};
			TILE_N = SPR_LIST.TN + {11'b00000000000,TILE_OFFS} + {15'b000000000000000,TILE_X};
			
			if (DOT_CE_R) begin
				SPR_ROM_ADDR <= SPR_LIST.BPP ? {TILE_N,DOT_Y,DOT_X[3:2]} : {1'b0,TILE_N,DOT_Y,DOT_X[3:3]};
				RENDER_ROM_CYCLE <= SPR_FETCH_RUN | BG_FETCH_EN;
			end
		end
	end
	
	//Cycle1
	bit  [31: 0] SPR_FETCH_PATT;
	bit  [ 7: 0] SPR_DRAW_PAL2;
	bit  [ 2: 0] SPR_DRAW_A2;
	bit  [ 1: 0] SPR_DRAW_PRI2;
	bit          SPR_DRAW_BPP2;
	bit          SPR_DRAW_LINE2;
	bit  [15: 0] SPR_FETCH_X2;
	bit  [15: 0] SPR_FETCH_XINC2;
	bit  [ 9: 0] SPR_LINE_X2;
	bit  [ 2: 0] SPR_DOT_NUM2;
	bit          SPR_LINE_FILL2;
	always @(posedge CLK or negedge RST_N) begin		
		bit  [15: 0] SPR_FETCH_X2_NEW;
		bit  [ 2: 0] LINE_PIX_CNT;
		bit  [ 9: 0] SPR_LINE_X2_NEW;
		
		if (!RST_N) begin
			SPR_FETCH_X2 <= '0;
			SPR_FETCH_PATT <= '0;
			SPR_LINE_FILL2 <= 0;
		end else if (EN) begin
			SPR_FETCH_X2_NEW = SPR_FETCH_X2 + SPR_FETCH_XINC2;
			SPR_LINE_X2_NEW = SPR_LINE_X2 + 10'h001;
			if (SPR_LINE_FILL2) begin
				SPR_FETCH_X2 <= SPR_FETCH_X2_NEW;
				SPR_LINE_X2 <= SPR_LINE_X2_NEW;
				if (LINE_PIX_CNT == SPR_DOT_NUM2) begin
					SPR_LINE_FILL2 <= 0;
				end
				LINE_PIX_CNT <= LINE_PIX_CNT + 3'd1;
			end

			if (DOT_CE_R) begin
				SPR_FETCH_PATT <= SpriteDataFlip(ROM_D, SPR_FETCH_FLIPX1, SPR_FETCH_BPP1);
				SPR_FETCH_X2 <= SPR_FETCH_X1;
				SPR_FETCH_XINC2 <= SPR_FETCH_XINC1;
				SPR_DRAW_PAL2 <= SPR_FETCH_PAL1;
				SPR_DRAW_A2 <= SPR_FETCH_A1;
				SPR_DRAW_PRI2 <= SPR_FETCH_PRI1;
				SPR_DRAW_BPP2 <= SPR_FETCH_BPP1;
				SPR_LINE_FILL2 <= SPR_LINE_FILL1;
				SPR_DRAW_LINE2 <= SPR_DRAW_LINE1;
				SPR_DOT_NUM2 <= SPR_DRAW_DOT_NUM1;
				if (SPR_DRAW_FIRST1 && SPR_LINE_FILL1) SPR_LINE_X2 <= SPR_DRAW_X1;
				LINE_PIX_CNT <= '0;
			end
		end
	end
	
	//Cycle2
	bit  [ 7: 0] SPR_DRAW_PIX;
	always_comb begin
		if (!SPR_DRAW_BPP2)
			case (SPR_FETCH_X2[12:10])
				3'h0: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[31:28]};
				3'h1: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[27:24]};
				3'h2: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[23:20]};
				3'h3: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[19:16]};
				3'h4: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[15:12]};
				3'h5: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[11: 8]};
				3'h6: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[ 7: 4]};
				3'h7: SPR_DRAW_PIX <= {4'h0,SPR_FETCH_PATT[ 3: 0]};
			endcase
		else
			case (SPR_FETCH_X2[11:10])
				2'h0: SPR_DRAW_PIX <= SPR_FETCH_PATT[31:24];
				2'h1: SPR_DRAW_PIX <= SPR_FETCH_PATT[23:16];
				2'h2: SPR_DRAW_PIX <= SPR_FETCH_PATT[15: 8];
				2'h3: SPR_DRAW_PIX <= SPR_FETCH_PATT[ 7: 0];
			endcase
	end
	wire         SPR_LINE_WREN = SPR_LINE_FILL2 & ~SPR_LINE_X2[9] & |SPR_DRAW_PIX;
	wire [20: 0] SPR_LINE_DIN = {SPR_DRAW_PRI2,SPR_DRAW_A2,SPR_DRAW_PAL2,SPR_DRAW_PIX};
	
	bit  [20: 0] SPR_LINE_Q[2];
	wire [ 8: 0] SPR_LINE0_WA   = !SPR_DRAW_LINE2 ? SPR_LINE_X2[8:0] : BG_DISP_X;
	wire [20: 0] SPR_LINE0_DATA = !SPR_DRAW_LINE2 ? SPR_LINE_DIN : 21'h0;
	wire         SPR_LINE0_WE   = !SPR_DRAW_LINE2 ? SPR_LINE_WREN : DOT_CE_R;
	PSH2_SPR_LINE SPR_LINE0(CLK, SPR_LINE0_WA, SPR_LINE0_DATA, SPR_LINE0_WE, BG_DISP_X, SPR_LINE_Q[0]);
	
	wire [ 8: 0] SPR_LINE1_WA   =  SPR_DRAW_LINE2 ? SPR_LINE_X2[8:0] : BG_DISP_X;
	wire [20: 0] SPR_LINE1_DATA =  SPR_DRAW_LINE2 ? SPR_LINE_DIN : 21'h0;
	wire         SPR_LINE1_WE   =  SPR_DRAW_LINE2 ? SPR_LINE_WREN : DOT_CE_R;
	PSH2_SPR_LINE SPR_LINE1(CLK, SPR_LINE1_WA, SPR_LINE1_DATA, SPR_LINE1_WE, BG_DISP_X, SPR_LINE_Q[1]);
	
	wire [20: 0] SPR_LINE_DOUT = SPR_LINE_Q[~SPR_DRAW_LINE2];
	
	
	/***************BG***************/
	bit          BG_EN[4],BG_BPP[4],BG_SIZE[4],BG_LINE_EN[4];
	assign BG_EN   = '{REG7.BG0CTRL[3] & REG6.BG0BANK >= 5'h0A,
	                   REG7.BG1CTRL[3] & REG6.BG1BANK >= 5'h0A,
							 REG7.BG2CTRL[3] & REG6.BG2BANK >= 5'h0A,
							 REG7.BG3CTRL[3] & REG6.BG3BANK >= 5'h0A};
	assign BG_BPP  = '{REG7.BG0CTRL[2],REG7.BG1CTRL[2],REG7.BG2CTRL[2],REG7.BG3CTRL[2]};
	assign BG_SIZE = '{REG7.BG0CTRL[0],REG7.BG1CTRL[0],REG7.BG2CTRL[0],REG7.BG3CTRL[0]};
							
	BG_t         BG_PARAM[4];
	assign BG_LINE_EN = '{BG_PARAM[0].ATTR.BANK >= {4'h0,REGS[4][15:12]} & BG_PARAM[0].ATTR.BANK <= 8'h1F,
						       BG_PARAM[1].ATTR.BANK >= {4'h0,REGS[4][15:12]} & BG_PARAM[1].ATTR.BANK <= 8'h1F,
						       BG_PARAM[2].ATTR.BANK >= {4'h0,REGS[4][15:12]} & BG_PARAM[2].ATTR.BANK <= 8'h1F,
						       BG_PARAM[3].ATTR.BANK >= {4'h0,REGS[4][15:12]} & BG_PARAM[3].ATTR.BANK <= 8'h1F};
	
	bit          BG_RENDER_ACTIVE;
	bit  [ 7: 0] BG_RENDER_LINE;
	always @(posedge CLK or negedge RST_N) begin				
		if (!RST_N) begin
			BG_RENDER_ACTIVE <= 0;
			BG_RENDER_LINE <= '0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				if (HCNT == 9'h162) begin
					BG_RENDER_LINE = VCNT[7:0] + 8'd1;
					if (VCNT == 9'h1FF) begin
						 BG_RENDER_ACTIVE <= 1;
					end
				end
				if (HCNT == 9'h1FF && VCNT == VBLK_START - 9'd1) begin
					BG_RENDER_ACTIVE <= 0;
				end
			end
		end
	end
	
	//BG map
	bit          BGRAM_INC;
	BGRAMSlot_t  BGRAM_SLOT;
	bit  [ 1: 0] BGRAM_N;
	always_comb begin
		{BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b0,BGRAM_EMPTY,2'h0};
		if (HCNT >= 9'h163 && HCNT <= 9'h177) begin
			case ({HCNT,DOTCLK_DIV[1]})
				{9'h163,1'b1}: if (BG_EN[0]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_SCROLL,2'h0};
				{9'h164,1'b1}: if (BG_EN[2]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_SCROLL,2'h2};
				{9'h165,1'b0}:                                                                      {BGRAM_SLOT,BGRAM_N} <= {BGRAM_PRECOL,2'h0};
				{9'h166,1'b0}: if (BG_EN[1]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_SCROLL,2'h1};
				{9'h167,1'b0}: if (BG_EN[3]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_SCROLL,2'h3};
				{9'h167,1'b1}: if (BG_EN[0]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_ATTR,2'h0};
				{9'h168,1'b1}: if (BG_EN[2]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_ATTR,2'h2};
				{9'h169,1'b0}:                                                                      {BGRAM_SLOT,BGRAM_N} <= {BGRAM_POSTCOL,2'h0};
				{9'h16A,1'b0}: if (BG_EN[1]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_ATTR,2'h1};
				{9'h16B,1'b0}: if (BG_EN[3]                                                       ) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_ATTR,2'h3};
				
				{9'h16C,1'b0}: if (BG_EN[0] && BG_LINE_EN[0]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h0};
				{9'h16D,1'b0}: if (BG_EN[2] && BG_LINE_EN[2]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h2};
				{9'h16E,1'b0}: if (BG_EN[0] && BG_LINE_EN[0]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h0};
				{9'h16E,1'b1}: if (BG_EN[1] && BG_LINE_EN[1]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h1};
				{9'h16F,1'b0}: if (BG_EN[2] && BG_LINE_EN[2]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h2};
				{9'h16F,1'b1}: if (BG_EN[3] && BG_LINE_EN[3]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h3};
				{9'h170,1'b0}: if (BG_EN[0] && BG_LINE_EN[0] && BG_X[0][3:2] == 2'b11 && BG_BPP[0]) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b0,BGRAM_TILE,2'h0};
				{9'h171,1'b0}: if (BG_EN[2] && BG_LINE_EN[2] && BG_X[2][3:2] == 2'b11 && BG_BPP[2]) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b0,BGRAM_TILE,2'h2};
				{9'h172,1'b1}: if (BG_EN[1] && BG_LINE_EN[1]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h1};
				{9'h173,1'b1}: if (BG_EN[3] && BG_LINE_EN[3]                                      ) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b1,BGRAM_TILE,2'h3};
				{9'h176,1'b1}: if (BG_EN[1] && BG_LINE_EN[1] && BG_X[1][3:2] == 2'b11 && BG_BPP[1]) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b0,BGRAM_TILE,2'h1};
				{9'h177,1'b1}: if (BG_EN[3] && BG_LINE_EN[3] && BG_X[3][3:2] == 2'b11 && BG_BPP[3]) {BGRAM_INC,BGRAM_SLOT,BGRAM_N} <= {1'b0,BGRAM_TILE,2'h3};
				default: {BGRAM_SLOT,BGRAM_N} <= {BGRAM_EMPTY,2'h0};
			endcase
		end
		else if (HCNT >= 9'h1FC || HCNT <= 9'h13F) begin
			if (BG_EN[0] && BG_LINE_EN[0] && {HCNT[0:0],DOTCLK_DIV[1]} == {1'h0,1'b0} && BG_X[0][3:0] ==? 4'b111?) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_TILE,2'h0};
			if (BG_EN[1] && BG_LINE_EN[1] && {HCNT[0:0],DOTCLK_DIV[1]} == {1'h0,1'b1} && BG_X[1][3:0] ==? 4'b111?) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_TILE,2'h1};
			if (BG_EN[2] && BG_LINE_EN[2] && {HCNT[0:0],DOTCLK_DIV[1]} == {1'h1,1'b0} && BG_X[2][3:0] ==? 4'b111?) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_TILE,2'h2};
			if (BG_EN[3] && BG_LINE_EN[3] && {HCNT[0:0],DOTCLK_DIV[1]} == {1'h1,1'b1} && BG_X[3][3:0] ==? 4'b111?) {BGRAM_SLOT,BGRAM_N} <= {BGRAM_TILE,2'h3};
		end
	end
	
	bit  [ 8: 0] BG_X[4];
	bit  [15: 1] BG_ADDR;
	always_comb begin
		bit  [ 4: 0] BG_BANK[4];
		bit          BG_MODE[4];
		bit  [ 7: 0] BG_LINE;
		bit  [ 8: 0] OFFS_X,OFFS_Y;
		bit  [ 4: 0] BG_TILE_X,BG_TILE_Y;
		
		BG_BANK = '{REG6.BG0BANK,REG6.BG1BANK,REG6.BG2BANK,REG6.BG3BANK};
		BG_MODE = '{REG6.BG0MODE,REG6.BG1MODE,REG6.BG2MODE,REG6.BG3MODE};
		BG_LINE = BG_MODE[BGRAM_N] ? BG_RENDER_LINE : {6'b111111,BGRAM_N};
		
		OFFS_X = BG_X[BGRAM_N];
		OFFS_Y = {1'b0,BG_RENDER_LINE} - BG_PARAM[BGRAM_N].SCROLL.Y;
		BG_TILE_X = OFFS_X[8:4];
		BG_TILE_Y = {OFFS_Y[8]&BG_SIZE[BGRAM_N],OFFS_Y[7:4]};
		
		case (BGRAM_SLOT)
			BGRAM_PRECOL:  BG_ADDR <= {REG7.LINEBANK,1'b0,BG_RENDER_LINE,DOTCLK_DIV[0]};
			BGRAM_POSTCOL: BG_ADDR <= {REG7.LINEBANK,1'b1,BG_RENDER_LINE,DOTCLK_DIV[0]};
			BGRAM_SCROLL:  BG_ADDR <= {BG_BANK[BGRAM_N],1'b0,BG_LINE,DOTCLK_DIV[0]};
			BGRAM_ATTR:    BG_ADDR <= {BG_BANK[BGRAM_N],1'b1,BG_LINE,DOTCLK_DIV[0]};
			BGRAM_TILE:    BG_ADDR <= {{BG_PARAM[BGRAM_N].ATTR.BANK[4:0],4'b0000}+{4'b0000,BG_TILE_Y},BG_TILE_X,DOTCLK_DIV[0]};
			default:       BG_ADDR <= '0;
		endcase
	end
	
	bit  [23: 0] BG_PRE_COLOR,BG_POST_COLOR;
	bit  [ 7: 0] BG_POST_ALPHA;
	always @(posedge CLK or negedge RST_N) begin	
		bit  [15: 0] SRAM_DL;	
		bit  [16: 0] BG_X_INC[4];
		bit  [ 7: 0] BG_X_FRAC[4];
		bit  [ 8: 0] OFFSX;
		bit          TILE_SET;	
		
		if (!RST_N) begin
			BG_X <= '{4{'0}};
			BG_PARAM <= '{4{BG_INIT}};
		end else if (EN) begin
			BG_X_INC[0] = {9'h001,BG_PARAM[0].ATTR.ZOOM};
			BG_X_INC[1] = {9'h001,BG_PARAM[1].ATTR.ZOOM};
			BG_X_INC[2] = {9'h001,BG_PARAM[2].ATTR.ZOOM};
			BG_X_INC[3] = {9'h001,BG_PARAM[3].ATTR.ZOOM};
			
			if (DOT_CE_R) begin;
				if (HCNT >= 9'h1FF || HCNT <= 9'h13F) begin
					{BG_X[0],BG_X_FRAC[0]} <= {BG_X[0],BG_X_FRAC[0]} + BG_X_INC[0];
					{BG_X[1],BG_X_FRAC[1]} <= {BG_X[1],BG_X_FRAC[1]} + BG_X_INC[1];
					{BG_X[2],BG_X_FRAC[2]} <= {BG_X[2],BG_X_FRAC[2]} + BG_X_INC[2];
					{BG_X[3],BG_X_FRAC[3]} <= {BG_X[3],BG_X_FRAC[3]} + BG_X_INC[3];
				end
			end
			
			if (CE) begin
				OFFSX = 9'h0 - BG_PARAM[BGRAM_N].SCROLL.X;
				if (!DOTCLK_DIV[0]) begin
					SRAM_DL <= SRAM_DI;
				end
				else begin
					TILE_SET = BG_X[BGRAM_N][4];
					case (BGRAM_SLOT)
						BGRAM_PRECOL:  BG_PRE_COLOR <= {SRAM_DL,SRAM_DI[15:8]};
						BGRAM_POSTCOL: {BG_POST_COLOR,BG_POST_ALPHA} <= {SRAM_DL,SRAM_DI};
						BGRAM_SCROLL:  BG_PARAM[BGRAM_N].SCROLL <= {SRAM_DL,SRAM_DI};
						BGRAM_ATTR:    BG_PARAM[BGRAM_N].ATTR <= {SRAM_DL,SRAM_DI};
						BGRAM_TILE:    BG_PARAM[BGRAM_N].TILE[TILE_SET] <= {SRAM_DL,SRAM_DI};
						default:;
					endcase
					
					if (BGRAM_SLOT == BGRAM_ATTR) begin
						{BG_X[BGRAM_N],BG_X_FRAC[BGRAM_N]} <= {OFFSX,8'h00};
					end
					if (BGRAM_SLOT == BGRAM_TILE) begin
						if (BGRAM_INC) begin
							{BG_X[BGRAM_N],BG_X_FRAC[BGRAM_N]} <= {BG_X[BGRAM_N],BG_X_FRAC[BGRAM_N]} + (BG_X_INC[BGRAM_N] << 4);
						end
					end
				end
			end
		end
	end
	
	//BG fetch
	//Cycle0
	bit  [ 3: 0] BGROM_ACCESS0;
	always_comb begin	
		BGROM_ACCESS0 <= '0;
		if (HCNT >= 9'h16C && HCNT <= 9'h173) begin
			case (HCNT)
				9'h16C: if (BG_EN[0] && BG_LINE_EN[0]) begin BGROM_ACCESS0[0] <= 1; end
				9'h16D: if (BG_EN[2] && BG_LINE_EN[2]) begin BGROM_ACCESS0[2] <= 1; end
				9'h16E: if (BG_EN[0] && BG_LINE_EN[0]) begin BGROM_ACCESS0[0] <= 1; end
				9'h16F: if (BG_EN[1] && BG_LINE_EN[1]) begin BGROM_ACCESS0[1] <= 1; end
				9'h170: if (BG_EN[2] && BG_LINE_EN[2]) begin BGROM_ACCESS0[2] <= 1; end
				9'h173: if (BG_EN[1] && BG_LINE_EN[1]) begin BGROM_ACCESS0[1] <= 1; end
				default: ;
			endcase
		end
		else if (HCNT >= 9'h1FC || HCNT <= 9'h13F) begin
			if (BG_EN[0] && BG_LINE_EN[0] && HCNT[1:0] == 2'h0) begin BGROM_ACCESS0[0] <= 1; end
			if (BG_EN[1] && BG_LINE_EN[1] && HCNT[1:0] == 2'h1) begin BGROM_ACCESS0[1] <= 1; end
			if (BG_EN[2] && BG_LINE_EN[2] && HCNT[1:0] == 2'h2) begin BGROM_ACCESS0[2] <= 1; end
			if (BG_EN[3] && BG_LINE_EN[3] && HCNT[1:0] == 2'h3) begin BGROM_ACCESS0[3] <= 1; end
		end
	end
	
	bit  [ 8: 0] BG_ROM_X[4];
	bit  [ 3: 0] BGROM_ACCESS1;
	bit  [ 1: 0] BGROM_NUM;
	bit  [24: 0] BG_ROM_ADDR;
	bit  [ 7: 0] BG_TILE_PAL1;
	bit  [ 2: 0] BG_ROM_OFFS1;
	always @(posedge CLK or negedge RST_N) begin	
		bit  [ 1: 0] BG_N;
		bit  [ 3: 0] PIX_X,PIX_Y;
		bit          TILE_SET;
		bit  [18: 0] TILE_NUM;
		bit  [16: 0] BG_ROM_X_INC;
		bit  [ 7: 0] BG_ROM_X_FRAC[4];
		
		if (!RST_N) begin
			BG_ROM_X <= '{4{'0}};
			BG_ROM_ADDR <= '0;
			BG_TILE_PAL1 <= '0;
			BGROM_ACCESS1 <= '0;
			BGROM_NUM <= '0;
		end else if (EN) begin
			BG_N = BGROM_ACCESS0[3] ? 2'd3 : BGROM_ACCESS0[2] ? 2'd2 : BGROM_ACCESS0[1] ? 2'd1 : 2'd0;

			PIX_X = BG_ROM_X[BG_N][3:0];
			PIX_Y = BG_RENDER_LINE[3:0] - BG_PARAM[BG_N].SCROLL.Y[3:0];
			TILE_SET = BG_ROM_X[BG_N][4];
			TILE_NUM = BG_PARAM[BG_N].TILE[TILE_SET].NUM;
			
			if (DOT_CE_R) begin
				if (HCNT >= 9'h168 && HCNT <= 9'h16B) begin
					{BG_ROM_X[HCNT[1:0]],BG_ROM_X_FRAC[HCNT[1:0]]} <= {9'h0 - BG_PARAM[HCNT[1:0]].SCROLL.X,8'h00};
				end else if (|BGROM_ACCESS0) begin
					BG_ROM_X_INC = {9'h001,BG_PARAM[BG_N].ATTR.ZOOM};
					{BG_ROM_X[BG_N],BG_ROM_X_FRAC[BG_N]} <= {BG_ROM_X[BG_N],BG_ROM_X_FRAC[BG_N]} + (BG_ROM_X_INC << 2); 
				end
				BG_ROM_ADDR <= BG_BPP[BG_N] ? {TILE_NUM,PIX_Y,PIX_X[3:2]} : {1'b0,TILE_NUM,PIX_Y,PIX_X[3:3]};
				BG_TILE_PAL1 <= BG_PARAM[BG_N].TILE[TILE_SET].PAL;
				BG_ROM_OFFS1 <= BG_ROM_X[BG_N][2:0];
				BGROM_NUM <= BG_N; 
				BGROM_ACCESS1 <= BGROM_ACCESS0; 
			end
		end
	end
	
	//Cycle1
	bit  [31: 0] BG_FETCH_DATA;
	bit  [ 7: 0] BG_FETCH_PAL;
	bit  [ 2: 0] BG_FETCH_OFFS;
	bit  [ 1: 0] BG_FETCH_NUM;
	bit  [ 3: 0] BG_FETCH_ACCESS;
	always @(posedge CLK or negedge RST_N) begin			
		if (!RST_N) begin
			BG_FETCH_DATA <= '0;
			BG_FETCH_PAL <= '0;
			BG_FETCH_OFFS <= '0;
			BG_FETCH_NUM <= '0;
			BG_FETCH_ACCESS <= '0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				BG_FETCH_DATA <= ROM_D;
				BG_FETCH_PAL <= BG_TILE_PAL1;
				BG_FETCH_OFFS <= BG_ROM_OFFS1;
				BG_FETCH_NUM <= BGROM_NUM;
				BG_FETCH_ACCESS <= BGROM_ACCESS1;
			end
		end
	end
	
	//Cycle2
	bit  [31: 0] BG_FETCH_DATA2[4];
	bit  [ 7: 0] BG_FETCH_PAL2[4];
	bit  [ 3: 0] BG_FETCH_ACCESS2;
	always @(posedge CLK or negedge RST_N) begin			
		bit  [ 1: 0] N;
		
		if (!RST_N) begin
			BG_FETCH_DATA2 <= '{4{'0}};
			BG_FETCH_PAL2 <= '{4{'0}};
			BG_FETCH_ACCESS2 <= '0;
		end else if (EN) begin
			N = BG_FETCH_NUM;
			if (DOT_CE_R) begin
				BG_FETCH_ACCESS2 <= BG_FETCH_ACCESS;
				
				if (BG_FETCH_ACCESS[N]) begin
					BG_FETCH_DATA2[N] <= BG_BPP[N]         ? {BG_FETCH_DATA[31:24],BG_FETCH_DATA[23:16],BG_FETCH_DATA[15:8],BG_FETCH_DATA[7:0]} : 
											   !BG_FETCH_OFFS[2] ? {4'h0,BG_FETCH_DATA[31:28],4'h0,BG_FETCH_DATA[27:24],4'h0,BG_FETCH_DATA[23:20],4'h0,BG_FETCH_DATA[19:16]} :
																	     {4'h0,BG_FETCH_DATA[15:12],4'h0,BG_FETCH_DATA[11: 8],4'h0,BG_FETCH_DATA[ 7: 4],4'h0,BG_FETCH_DATA[ 3: 0]};
					BG_FETCH_PAL2[N] <= BG_FETCH_PAL;
				end
				
`ifdef DEBUG
				if (HCNT == 9'h1FE && VCNT == 9'h06D) begin
					DBG_BG_ROM_X2 <= BG_ROM_X[2];
				end
				if (HCNT == 9'h1FF && VCNT == 9'h06D) begin
					DBG_ROM_ADDR2 <= DBG_ROM_ADDR;
				end
				if (HCNT == 9'h000 && VCNT == 9'h06E && BG_FETCH_ACCESS[2]) begin
					DBG_BG_FETCH_DATA2 <= BG_FETCH_DATA;
				end
`endif
			end
		end
	end
	
	//Cycle3
	bit  [ 7: 0] BG_PIX_PAL[4][2];
	bit  [ 7: 0] BG_PIX_ROW[4][8];
	always @(posedge CLK or negedge RST_N) begin			
		if (!RST_N) begin
		end else if (EN) begin
			if (DOT_CE_R) begin				
				if ((HCNT >= 9'h16D && HCNT <= 9'h17F && BG_FETCH_ACCESS2[0]) || (HCNT <= 9'h13F && HCNT[1:0] == 2'b01)) begin
					{BG_PIX_ROW[0][0],BG_PIX_ROW[0][1],BG_PIX_ROW[0][2],BG_PIX_ROW[0][3]} <= {BG_PIX_ROW[0][4],BG_PIX_ROW[0][5],BG_PIX_ROW[0][6],BG_PIX_ROW[0][7]};
					{BG_PIX_ROW[0][4],BG_PIX_ROW[0][5],BG_PIX_ROW[0][6],BG_PIX_ROW[0][7]} <= BG_FETCH_DATA2[0];
					BG_PIX_PAL[0][0] <= BG_PIX_PAL[0][1];
					BG_PIX_PAL[0][1] <= BG_FETCH_PAL2[0];
				end
				if ((HCNT >= 9'h16D && HCNT <= 9'h17F && BG_FETCH_ACCESS2[1]) || (HCNT <= 9'h13F && HCNT[1:0] == 2'b01)) begin
					{BG_PIX_ROW[1][0],BG_PIX_ROW[1][1],BG_PIX_ROW[1][2],BG_PIX_ROW[1][3]} <= {BG_PIX_ROW[1][4],BG_PIX_ROW[1][5],BG_PIX_ROW[1][6],BG_PIX_ROW[1][7]};
					{BG_PIX_ROW[1][4],BG_PIX_ROW[1][5],BG_PIX_ROW[1][6],BG_PIX_ROW[1][7]} <= BG_FETCH_DATA2[1];
					BG_PIX_PAL[1][0] <= BG_PIX_PAL[1][1];
					BG_PIX_PAL[1][1] <= BG_FETCH_PAL2[1];
				end
				if ((HCNT >= 9'h16D && HCNT <= 9'h17F && BG_FETCH_ACCESS2[2]) || (HCNT <= 9'h13F && HCNT[1:0] == 2'b01)) begin
					{BG_PIX_ROW[2][0],BG_PIX_ROW[2][1],BG_PIX_ROW[2][2],BG_PIX_ROW[2][3]} <= {BG_PIX_ROW[2][4],BG_PIX_ROW[2][5],BG_PIX_ROW[2][6],BG_PIX_ROW[2][7]};
					{BG_PIX_ROW[2][4],BG_PIX_ROW[2][5],BG_PIX_ROW[2][6],BG_PIX_ROW[2][7]} <= BG_FETCH_DATA2[2];
					BG_PIX_PAL[2][0] <= BG_PIX_PAL[2][1];
					BG_PIX_PAL[2][1] <= BG_FETCH_PAL2[2];
				end
				if ((HCNT >= 9'h16D && HCNT <= 9'h17F && BG_FETCH_ACCESS2[3]) || (HCNT <= 9'h13F && HCNT[1:0] == 2'b01)) begin
					{BG_PIX_ROW[3][0],BG_PIX_ROW[3][1],BG_PIX_ROW[3][2],BG_PIX_ROW[3][3]} <= {BG_PIX_ROW[3][4],BG_PIX_ROW[3][5],BG_PIX_ROW[3][6],BG_PIX_ROW[3][7]};
					{BG_PIX_ROW[3][4],BG_PIX_ROW[3][5],BG_PIX_ROW[3][6],BG_PIX_ROW[3][7]} <= BG_FETCH_DATA2[3];
					BG_PIX_PAL[3][0] <= BG_PIX_PAL[3][1];
					BG_PIX_PAL[3][1] <= BG_FETCH_PAL2[3];
				end
			end
		end
	end
	assign BG_FETCH_EN = |BGROM_ACCESS0;
	
	assign ROM_ADDR = |BGROM_ACCESS1 ? BG_ROM_ADDR : SPR_ROM_ADDR;
	assign RENDER_SRAM_CYCLE = (BGRAM_SLOT != BGRAM_EMPTY) || (SPR_LOAD_RUN && SPR_LOAD_STATE != 3'h7);
	
	//Pixel out
	//Cycle4
	bit  [ 8: 0] BG_DISP_X;
	always @(posedge CLK or negedge RST_N) begin				
		if (!RST_N) begin
			BG_DISP_X <= '0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				BG_DISP_X <= BG_DISP_X + 9'd1;
				if (HCNT == 9'h1FD) begin
					BG_DISP_X <= '0;
				end
			end
		end
	end
	
	bit  [ 7: 0] BG_OUT_PIX[4];
	bit  [ 7: 0] BG_OUT_PAL[4];
	bit  [ 7: 0] SPR_OUT_PIX;
	bit  [ 7: 0] SPR_OUT_PAL,SPR_OUT_ALPHA;
	bit  [ 2: 0] DOT_FST,DOT_SEC,DOT_THD,DOT_FTH;	
	always @(posedge CLK or negedge RST_N) begin	
		bit  [ 2: 0] BG_PIX_POS[4];
		bit  [ 7: 0] BG_PIX[4];
		bit  [ 7: 0] BG_PAL[4];
		bit  [ 2: 0] BG_PRI[4];
		bit          BG_VIS[4];	
		bit  [ 2: 0] SPR_PRI;	
		bit          SPR_VIS;
		bit  [ 2: 0] POST_PRI;
		bit          POST_VIS;
		bit  [ 2: 0] FST_PRI,SEC_PRI,THD_PRI,FTH_PRI;
		bit  [ 2: 0] FST,SEC,THD,FTH;
		
		if (!RST_N) begin
			BG_OUT_PIX <= '{4{'0}};
			BG_OUT_PAL <= '{4{'0}};
			{DOT_FST,DOT_SEC,DOT_THD,DOT_FTH} <= '0;
		end else if (EN) begin		
			for (int i=0;i<4;i++) begin
				BG_PIX_POS[i] = {1'b0,BG_DISP_X[1:0]} + {1'b0,2'h0-BG_PARAM[i].SCROLL.X[1:0]};
				BG_PIX[i] = BG_PIX_ROW[i][BG_PIX_POS[i]];
				BG_PAL[i] = BG_PIX_PAL[i][BG_PIX_POS[i][2]];
				BG_PRI[i] = BG_PARAM[i].ATTR.PRI;
				BG_VIS[i] = |BG_PIX[i] && BG_EN[i] && BG_LINE_EN[i] && SCRN_EN[i];
			end
			SPR_PRI = SPR_PRIO[SPR_LINE_DOUT[20:19]][2:0];
			SPR_VIS = |SPR_LINE_DOUT[7:0] && SCRN_EN[4];
			POST_PRI = REG2.POSTPRI[2:0];
			POST_VIS = SCRN_EN[5];
			
			if (DOT_CE_R) begin
				for (int i=0;i<4;i++) begin
					BG_OUT_PIX[i] <= BG_PIX[i];
					BG_OUT_PAL[i] <= BG_PAL[i];
				end
				SPR_OUT_PIX <= SPR_LINE_DOUT[7:0];
				SPR_OUT_PAL <= SPR_LINE_DOUT[15:8];
				SPR_OUT_ALPHA <= SPR_ALPHA[SPR_LINE_DOUT[18:16]];
				
				{FST,SEC,THD,FTH} = {3'h7,3'h7,3'h7,3'h7};
				{FST_PRI,SEC_PRI,THD_PRI,FTH_PRI} = {3'h0,3'h0,3'h0,3'h0};
				     if (SPR_PRI >= FST_PRI && SPR_VIS) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 3'd4; FST_PRI = SPR_PRI;
				end 
				
				     if (BG_PRI[0] >= FST_PRI && BG_VIS[0]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 3'd0; FST_PRI = BG_PRI[0];
				end 
				else if (BG_PRI[0] >= SEC_PRI && BG_VIS[0]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = 3'd0; SEC_PRI = BG_PRI[0];
				end 
				
				     if (BG_PRI[1] >= FST_PRI && BG_VIS[1]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 3'd1; FST_PRI = BG_PRI[1];
				end 
				else if (BG_PRI[1] >= SEC_PRI && BG_VIS[1]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = 3'd1; SEC_PRI = BG_PRI[1];
				end 
				else if (BG_PRI[1] >= THD_PRI && BG_VIS[1]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = 3'd1; THD_PRI = BG_PRI[1];
				end
				
				     if (BG_PRI[2] >= FST_PRI && BG_VIS[2]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 3'd2; FST_PRI = BG_PRI[2];
				end 
				else if (BG_PRI[2] >= SEC_PRI && BG_VIS[2]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = 3'd2; SEC_PRI = BG_PRI[2];
				end 
				else if (BG_PRI[2] >= THD_PRI && BG_VIS[2]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = 3'd2; THD_PRI = BG_PRI[2];
				end
				else if (BG_PRI[2] >= FTH_PRI && BG_VIS[2]) begin
					FTH = 3'd2;  FTH_PRI = BG_PRI[2];
				end
				
				     if (BG_PRI[3] >= FST_PRI && BG_VIS[3]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 3'd3; FST_PRI = BG_PRI[3];
				end 
				else if (BG_PRI[3] >= SEC_PRI && BG_VIS[3]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = 3'd3; SEC_PRI = BG_PRI[3];
				end
				else if (BG_PRI[3] >= THD_PRI && BG_VIS[3]) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = 3'd3; THD_PRI = BG_PRI[3];
				end
				else if (BG_PRI[3] >= FTH_PRI && BG_VIS[3]) begin
					FTH = 3'd3;  FTH_PRI = BG_PRI[3];
				end
				
				     if (POST_PRI >= FST_PRI && POST_VIS) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 3'd5; FST_PRI = POST_PRI;
				end
				else if (POST_PRI >= SEC_PRI && POST_VIS) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = 3'd5; SEC_PRI = POST_PRI;
				end 
				else if (POST_PRI >= THD_PRI && POST_VIS) begin
					FTH = THD;  FTH_PRI = THD_PRI;
					THD = 3'd5; THD_PRI = POST_PRI;
				end
				else if (POST_PRI >= FTH_PRI && POST_VIS) begin
					FTH = 3'd5;  FTH_PRI = POST_PRI;
				end
			
				DOT_FST <= FST;
				DOT_SEC <= SEC;
				DOT_THD <= THD;
				DOT_FTH <= FTH;
			end
		end
	end
	
	bit  [11: 0] BG_COLOR;
	always_comb begin
		case (DOTCLK_DIV)
			2'h0:    BG_COLOR <= DOT_FTH <= 3'h3 ? {BG_OUT_PAL[DOT_FTH[1:0]],4'h0} + {4'h0,BG_OUT_PIX[DOT_FTH[1:0]]} : {SPR_OUT_PAL,4'h0} + {4'h0,SPR_OUT_PIX};
			2'h1:    BG_COLOR <= DOT_THD <= 3'h3 ? {BG_OUT_PAL[DOT_THD[1:0]],4'h0} + {4'h0,BG_OUT_PIX[DOT_THD[1:0]]} : {SPR_OUT_PAL,4'h0} + {4'h0,SPR_OUT_PIX};
			2'h2:    BG_COLOR <= DOT_SEC <= 3'h3 ? {BG_OUT_PAL[DOT_SEC[1:0]],4'h0} + {4'h0,BG_OUT_PIX[DOT_SEC[1:0]]} : {SPR_OUT_PAL,4'h0} + {4'h0,SPR_OUT_PIX};
			default: BG_COLOR <= DOT_FST <= 3'h3 ? {BG_OUT_PAL[DOT_FST[1:0]],4'h0} + {4'h0,BG_OUT_PIX[DOT_FST[1:0]]} : {SPR_OUT_PAL,4'h0} + {4'h0,SPR_OUT_PIX};
		endcase
	end
	
	bit  [23: 0] OUT_RGB;
	always @(posedge CLK or negedge RST_N) begin
		bit  [23: 0] TOP_RGB, BOT_RGB, TEMP_RGB;
		bit  [ 7: 0] TOP_A;
		bit  [ 2: 0] LAYER;
		bit  [ 7: 0] PIX, ALPHA;
		bit          POST;
	
		if (!RST_N) begin
			BOT_RGB <= '0;
			OUT_RGB <= '0;
		end else if (EN) begin
			case (DOTCLK_DIV)
				2'h0:    LAYER = DOT_FTH;
				2'h1:    LAYER = DOT_THD;
				2'h2:    LAYER = DOT_SEC;
				default: LAYER = DOT_FST;
			endcase
			PIX   = LAYER <= 3'h3 ? BG_OUT_PIX[LAYER[1:0]]          : LAYER == 3'h4 ? SPR_OUT_PIX   : 8'h00;
			ALPHA = LAYER <= 3'h3 ? BG_PARAM[LAYER[1:0]].ATTR.ALPHA : LAYER == 3'h4 ? SPR_OUT_ALPHA : LAYER == 3'h5 ? BG_POST_ALPHA : 8'h00;
			POST  = LAYER == 3'h5;
			
			if (CE) begin
				TOP_RGB = LAYER <= 3'h4 ? PAL_Q : LAYER == 3'h5 ? BG_POST_COLOR : BG_PRE_COLOR;
				TOP_A = POST ? (ALPHA[7] ? 8'h00 : ~{ALPHA[6:0],1'b0}) : !ALPHA[7] ? {ALPHA[5:0],ALPHA[5:4]} : PIX[7:6] == 2'b11 ? {PIX[5:0],PIX[5:4]} : 8'h00;
				
				if (TOP_A == 8'h00) begin
					TEMP_RGB = TOP_RGB;
				end
				else if (TOP_A == 8'hFF) begin
					TEMP_RGB = DOTCLK_DIV == 2'h0 ? BG_PRE_COLOR : BOT_RGB;
				end
				else begin
					TEMP_RGB = RGBBlend(DOTCLK_DIV == 2'h0 ? BG_PRE_COLOR : BOT_RGB, TOP_RGB, TOP_A);
				end
				case (DOTCLK_DIV)
					2'h0,
					2'h1,
					2'h2: BOT_RGB <= TEMP_RGB;
					2'h3: OUT_RGB <= TEMP_RGB;
				endcase
			end
		end
	end
	assign {R,G,B} = OUT_RGB;
	
`ifdef DEBUG
	assign DBG_REGS = REGS[0]^REGS[1]^REGS[2]^REGS[3]^REGS[4]^REGS[5]^REGS[6]^REGS[7];
	assign DBG_BG_ADDR = {BG_ADDR,1'b0};
	assign DBG_SPR_ADDR = {SPR_ADDR,1'b0};
	assign DBG_ROM_ADDR = {ROM_A,2'b00};
	assign DBG_SPR_LIST = SPR_LIST;
`endif
	
endmodule
