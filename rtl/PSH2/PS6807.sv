// synopsys translate_off
`define SIM
// synopsys translate_on

module PS6807 
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE,
	
	input      [14: 1] A,
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
	output             DCLK1,
	output             DCLK2,
	output             HS_N,
	output             VS_N,
	output             HBL_N,
	output             VBL_N,
	output             V240,
	
	output reg [ 7: 0] EEP_OUT,
	input      [ 7: 0] EEP_IN,
	
	input      [ 5: 0] SCRN_EN,
	input      [ 8: 0] HS_OFFS
	
`ifdef DEBUG
	                   ,
	output     [31: 0] DBG_REGS,
	output     [15: 0] DBG_BG_ADDR,DBG_SPR_ADDR,
	output     [26: 0] DBG_ROM_ADDR,
	output SpriteFetch_t DBG_SPR_LIST
`endif
);

	import PS6807_PKG::*;
	
	bit  [31: 0] VREGS[4];
	bit  [31: 0] SREGS[4];
	bit  [23: 0] SCREEN_BG_COL[2];
	bit  [ 7: 0] SCREEN_BRIGHT[2];
	bit  [15: 0] IACK;
	bit          VINT_PEND,VINT_REQ;
	
	bit          DOT_CE_R,DOT_CE_F;
	bit          RENDER_SRAM_CYCLE;
	bit          RENDER_ROM_CYCLE;
	bit          BG_FETCH_EN;
	bit  [24: 0] ROM_ADDR;
	
	wire         EEP_SEL  = (A >= (15'h3FE0>>1) && A <= (15'h3FE3>>1) && !CS_N);
	wire         IACK_SEL = (A >= (15'h3FE4>>1) && A <= (15'h3FE5>>1) && !CS_N);
	wire         VREG_SEL  = (A >= (15'h3FE8>>1) && A <= (15'h3FEF>>1) && !CS_N);
	wire         SREG_SEL  = (A >= (15'h3FF0>>1) && A <= (15'h3FFF>>1) && !CS_N);
	wire         IO_SPRRAM_SEL = (A >= (15'h0000>>1) && A <= (15'h37FF>>1) && !CS_N);
	wire         IO_PAL_SEL = (A >= (15'h4000>>1) && A <= (15'h5FFF>>1) && !CS_N);
	wire         IO_GFX_SEL = (A >= (15'h6000>>1) && A <= (15'h7FFF>>1) && !CS_N);
	
	bit          WE_N_OLD;
	always @(posedge CLK or negedge RST_N) begin
		bit          VINT_PEND_OLD,SPR_LOAD_RUN_OLD;
		
		if (!RST_N) begin
			VREGS <= '{4{'0}};
			SREGS <= '{4{'0}};
			IACK <= '0;
		end else if (EN) begin
			if (CE) begin
				WE_N_OLD <= &WE_N;
				if (VREG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!A[1] && !WE_N[1]) VREGS[A[3:2]][31:24] <= DI[15: 8];
					if (!A[1] && !WE_N[0]) VREGS[A[3:2]][23:16] <= DI[ 7: 0];
					if ( A[1] && !WE_N[1]) VREGS[A[3:2]][15: 8] <= DI[15: 8];
					if ( A[1] && !WE_N[0]) VREGS[A[3:2]][ 7: 0] <= DI[ 7: 0];
				end
				if (SREG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!A[1] && !WE_N[1]) SREGS[A[3:2]][31:24] <= DI[15: 8];
					if (!A[1] && !WE_N[0]) SREGS[A[3:2]][23:16] <= DI[ 7: 0];
					if ( A[1] && !WE_N[1]) SREGS[A[3:2]][15: 8] <= DI[15: 8];
					if ( A[1] && !WE_N[0]) SREGS[A[3:2]][ 7: 0] <= DI[ 7: 0];
				end
				if (EEP_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!A[1] && !WE_N[0]) EEP_OUT <= DI[7:0];
				end
				
				VINT_PEND_OLD <= VINT_PEND;
				SPR_LOAD_RUN_OLD <= SPR_LOAD_RUN;
				if (VINT_PEND && !VINT_PEND_OLD) begin
					VINT_REQ <= 1;
				end
				if (IACK[0] && !SPR_LOAD_RUN && SPR_LOAD_RUN_OLD) begin
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
	            EEP_SEL ? (!A[1] ? {8'h00,EEP_IN} : 16'h0000) : 
					VREG_SEL ? (!A[1] ? VREGS[A[3:2]][31:16] : VREGS[A[3:2]][15:0]) : 
	            SREG_SEL ? (!A[1] ? SREGS[A[3:2]][31:16] : SREGS[A[3:2]][15:0]) : 
					IO_SPRRAM_SEL ? IO_SRAM_DO : 
	            IO_PAL_SEL ? IO_PAL_DO : 
					IO_GFX_SEL ? IO_ROM_DO : 
					'0;
	assign WAIT_N = ~(IO_SPRRAM_SEL & IO_SPRRAM_WAIT) & ~(IO_PAL_SEL & IO_PAL_WAIT) & ~(IO_GFX_SEL & IO_ROM_WAIT);
	
	assign IRQ_N = ~VINT_REQ;
	
	assign SCREEN_BRIGHT[0] = SREGS[0][7:0];
	assign SCREEN_BG_COL[0] = SREGS[1][31:8];
	assign SCREEN_BRIGHT[1] = SREGS[2][7:0];
	assign SCREEN_BG_COL[1] = SREGS[3][31:8];
	
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
	assign SRAM_A = RENDER_SRAM_CYCLE ? {2'b00,SPR_ADDR} : IO_SPRRAM_CYCLE ? {2'b00,A[13:1]} : '0;
	assign SRAM_DO = DI;
	assign SRAM_OE_N = RENDER_SRAM_CYCLE ? 1'b0 : IO_SPRRAM_CYCLE ? RD_N : 1'b1;
	assign SRAM_WE_N = RENDER_SRAM_CYCLE ? 2'b11 : IO_SPRRAM_CYCLE ? WE_N : 2'b11;
	assign SRAM_CE_N = ~(RENDER_SRAM_CYCLE | IO_SPRRAM_CYCLE);
	
	//Palette
	bit  [15: 0] IO_PAL_DO;
	bit          IO_PAL_WAIT;
	bit          IO_PAL_CYCLE;
	always @(posedge CLK or negedge RST_N) begin
		bit          IO_PAL_SEL_OLD;
		
		if (!RST_N) begin
			IO_PAL_WAIT <= 0;
			IO_PAL_CYCLE <= 0;
		end else if (EN) begin
			IO_PAL_SEL_OLD <= IO_PAL_SEL;
			if (IO_PAL_SEL && !IO_PAL_SEL_OLD) begin
				IO_PAL_WAIT <= 1;
			end
			if (CE) begin
				if (!DOTCLK_DIV[0]) IO_PAL_CYCLE <= IO_PAL_WAIT;
				if (IO_PAL_CYCLE && DOTCLK_DIV[0]) begin
					IO_PAL_DO <= !A[1] ? PAL_Q[23:8] : {PAL_Q[7:0],8'h00};
					IO_PAL_CYCLE <= 0;
					IO_PAL_WAIT <= 0;
				end
			end
		end
	end
	
	wire [10: 0] PAL_RA = DOTCLK_DIV[0] ? A[12:2] : BG_COLOR[DOTCLK_DIV[1]];
	wire         PAL_WE = DOTCLK_DIV[0] ? IO_PAL_CYCLE & ~(&WE_N) : 1'b0;
	bit  [23: 0] PAL_Q;
	PSH2_PAL_RAM PALR(CLK, {1'b0,A[12:2]}, DI[15: 8], PAL_WE & ~A[1] & ~WE_N[1] & CE, {1'b0,PAL_RA}, PAL_Q[23:16]);
	PSH2_PAL_RAM PALG(CLK, {1'b0,A[12:2]}, DI[ 7: 0], PAL_WE & ~A[1] & ~WE_N[0] & CE, {1'b0,PAL_RA}, PAL_Q[15: 8]);
	PSH2_PAL_RAM PALB(CLK, {1'b0,A[12:2]}, DI[15: 8], PAL_WE &  A[1] & ~WE_N[1] & CE, {1'b0,PAL_RA}, PAL_Q[ 7: 0]);
	
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
	
	wire [24:0] TEMP_ROM_A = RENDER_ROM_CYCLE ? ROM_ADDR[24:0] : {VREGS[3][13:0],A[12:2]};
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
	
	wire [ 8: 0] DOT_PER_LINE = 9'd456;
	wire [ 8: 0] HSYNC_START = 9'h168 + HS_OFFS;
	wire [ 8: 0] VBLK_START = VREGS[2][15] == 1'b1 ? 9'h0F0 : 9'h0E0;
	wire [ 8: 0] VSYNC_START = VREGS[2][15] == 1'b1 ? 9'd237+9'd16 : 9'd237;
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
				if (HCNT == DOT_PER_LINE - 1) begin
					HCNT <= '0;
					
					VCNT <= VCNT + 9'd1;
					if (VCNT == 9'h100) begin
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
				
				if (HCNT == DOT_PER_LINE - 1 && VCNT == VSYNC_START - 9'd1) begin
					VSYNC <= 1;
				end
				if (HCNT == DOT_PER_LINE - 1 && VCNT == VSYNC_START + 9'd3 - 1) begin
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
				if (HCNT == DOT_PER_LINE - 1) begin
					HBLK <= 0;
				end
			end
		end
	end
	assign DCLK1 = DOTCLK_DIV[1];
	assign DCLK2 = ~DOTCLK_DIV[1];
	assign HS_N = ~HSYNC;
	assign VS_N = ~VSYNC;
	assign HBL_N = ~HBLK;
	assign VBL_N = ~VBLK;
	assign V240 = (VREGS[2][15] == 1'b1);
	
	bit  [ 8: 0] DISP_X;
	always @(posedge CLK or negedge RST_N) begin				
		if (!RST_N) begin
			DISP_X <= '0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				DISP_X <= DISP_X + 9'd1;
				if (HCNT == 9'h1C5) begin
					DISP_X <= '0;
				end
			end
		end
	end
	

	/***************Sprites***************/
	//Sprites load
	bit          SPR_LOAD_RUN;
	bit  [15: 1] SPR_LIST_ADDR,SPR_LOAD_ADDR;
	bit  [10: 0] SPR_LOAD_NUM,SPR_LIST_NUM;
	bit  [ 2: 0] SPR_LOAD_STATE;
	
	bit  [15: 0] SPR_NUM;
	bit  [ 9: 0] SPR_LOAD_OFFSY;
	bit  [ 7: 0] SPR_LOAD_ZOOMY;
	always @(posedge CLK or negedge RST_N) begin	
		bit          SPR_LOAD_PEND,SPR_LOAD_DONE;	
		bit          IACK0_OLD;	
		bit  [ 9: 0] SPR_Y;
		bit  [15: 0] SPR_ZOOMY_VAL;
		
		if (!RST_N) begin
			SPR_LIST_NUM <= '0;
			SPR_LOAD_NUM <= '0;
			SPR_LOAD_STATE <= '0;
			SPR_LOAD_RUN <= 0;
			SPR_LOAD_DONE <= 0;
			SPR_NUM <= '0;
			SPR_LOAD_PEND <= 0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				if (HCNT == 9'd456 - 1 && VCNT == 9'h1FF) begin
					SPR_LOAD_DONE <= 0;
				end
				if (HCNT == 9'd456 - 1 && VCNT == 9'h0FF && !SPR_LOAD_DONE) begin
					SPR_LOAD_PEND <= 1;
				end
			end
			
			if (CE) begin
				if (SPR_LOAD_PEND) begin
					SPR_LIST_NUM <= 11'h002;
					SPR_LOAD_NUM <= '0;
					SPR_LOAD_STATE <= '0;
					SPR_LOAD_RUN <= 1;
					SPR_LOAD_PEND <= 0;
				end
				
				IACK0_OLD <= IACK[0];
				if (IACK[0] && !IACK0_OLD) begin
					SPR_LIST_NUM <= 11'h002;
					SPR_LOAD_NUM <= '0;
					SPR_LOAD_STATE <= '0;
					SPR_LOAD_RUN <= 1;
					SPR_LOAD_DONE <= 1;
					SPR_LOAD_PEND <= 0;
				end
				
				if (SPR_LOAD_RUN) begin
					SPR_LOAD_STATE <= SPR_LOAD_STATE + 3'd1;
					if (SPR_LOAD_STATE == 3'h0) begin
						SPR_NUM <= SRAM_DI;
					end
					if (SPR_LOAD_STATE == 3'h5) begin
						SPR_LOAD_STATE <= '0;
						if (SPR_LIST_NUM == 11'h5FF || SPR_NUM[14]) begin
							SPR_LOAD_RUN <= 0;
						end else begin
							SPR_LIST_NUM <= SPR_LIST_NUM + 10'd1;
							if (!SPR_NUM[15]) SPR_LOAD_NUM <= SPR_LOAD_NUM + 10'd1;
						end
					end
					
					if (SPR_LOAD_STATE == 3'h0+1) begin
						SPR_Y <= SRAM_DI[9:0];
					end
					if (SPR_LOAD_STATE == 3'h1+1) begin
						SPR_LOAD_OFFSY <= (10'h000 - $signed(SPR_Y));
					end
				end
			end
		end
	end
	
	bit  [13: 1] SPR_ADDR;
	always_comb begin
		if (SPR_LOAD_STATE == 3'h0)
			SPR_ADDR <= 13'h1600 + {2'b00,SPR_LIST_NUM};
		else
			SPR_ADDR <= {1'b0,SPR_NUM[9:0],SPR_LOAD_STATE[1:0]-2'h1};
	end
	
	//Sprites eval
	bit          SPR_EVAL_RUN;
	bit  [10: 0] SPR_EVAL_SPRNUM;
	bit  [ 7: 0] SPR_EVAL_CNT;
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
				if (HCNT == 9'h165 && (!VBLK || VCNT >= 9'h1FD)) begin
					SPR_EVAL_SPRNUM <= '0;
					SPR_EVAL_CNT <= '0;
					SPR_EVAL_RUN <= 1;
					SPR_EVAL_VCNT <= VCNT[7:0] + 8'd3;
				end
			end
			if (CE) begin
				if (SPR_EVAL_RUN) begin
					if (SPR_EVAL_HIT) begin
						SPR_EVAL_CNT <= SPR_EVAL_CNT + 8'd1;
						SPR_EVAL_QUANTITY[SPR_EVAL_VCNT[0]] <= SPR_EVAL_CNT;
					end
					
					if (SPR_EVAL_SPRNUM == SPR_LOAD_NUM || (SPR_EVAL_HIT && SPR_EVAL_CNT == 8'hFF)) begin
						SPR_EVAL_RUN <= 0;
					end else begin
						SPR_EVAL_SPRNUM <= SPR_EVAL_SPRNUM + 11'd1;
					end
				end
			end
		end
	end
	
	wire [10: 0] SPR_LIST_Y_WA = SPR_LOAD_RUN ? SPR_LOAD_NUM : SPR_EVAL_SPRNUM;
	wire         SPR_LIST_Y_WE = (SPR_LOAD_RUN && SPR_LOAD_STATE == 3'h2+1) || SPR_EVAL_RUN;
	
	wire [ 9: 0] SPR_LIST_Y_DATA = SPR_LOAD_RUN ? SPR_LOAD_OFFSY[9:0] : SPR_EVAL_LIST_Y_Q + 10'd1;
	bit  [ 9: 0] SPR_EVAL_LIST_Y_Q;
	PSH2_SPRITE_LIST_Y #(11) SPR_EVAL_LIST_Y (CLK, SPR_LIST_Y_WA, {4'h0,SPR_LIST_Y_DATA}, SPR_LIST_Y_WE & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST_Y_Q);
	
	Sprite4_t SPR_EVAL_LIST;
	PSH2_SPRITE_LIST #(11) SPR_EVAL_LIST0(CLK, SPR_LOAD_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h0+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[63:48]);
	PSH2_SPRITE_LIST #(11) SPR_EVAL_LIST1(CLK, SPR_LOAD_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h1+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[47:32]);
	PSH2_SPRITE_LIST #(11) SPR_EVAL_LIST2(CLK, SPR_LOAD_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h2+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[31:16]);
	PSH2_SPRITE_LIST #(11) SPR_EVAL_LIST3(CLK, SPR_LOAD_NUM, SRAM_DI, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h3+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_LIST[15: 0]);
	
	bit  [15: 0] SPR_EVAL_SCREEN;
	PSH2_SPRITE_LIST #(11) SPR_EVAL_LIST4(CLK, SPR_LOAD_NUM, {15'h0000,SPR_NUM[13]}, SPR_LOAD_RUN & SPR_LOAD_STATE == 3'h0+1 & CE, SPR_EVAL_SPRNUM, SPR_EVAL_SCREEN);
	
	always_comb begin
		bit  [ 9: 0] SPR_OFFSY;
		bit  [ 3: 0] SPR_H;
		
		SPR_OFFSY = SPR_EVAL_LIST_Y_Q;
		SPR_H = SPR_EVAL_LIST.H;
		
		SPR_EVAL_HIT <= 0;
		if (SPR_OFFSY[9:8] == 2'b00 && SPR_OFFSY[7:0] <= {SPR_H,4'b1111}) SPR_EVAL_HIT <= 1;
	end
	
	//Sprite fetch
	//Cycle0
	//SCREEN(1), H(4), Y(8), W(4), X(10), FLIPY(1), FLIPX(1), PAL(6), TN(19)
	wire [76: 0] SPRITE_PARAM_DATA = {22'b0000000000000000000000,SPR_EVAL_SCREEN[0],SPR_EVAL_LIST.H,SPR_EVAL_LIST_Y_Q[7:0],SPR_EVAL_LIST.W,SPR_EVAL_LIST.X,SPR_EVAL_LIST.FLIPY,SPR_EVAL_LIST.FLIPX,SPR_EVAL_LIST.PAL,SPR_EVAL_LIST.TN};
	SpriteFetch_t SPR_LIST;
	PSH2_SPRITE_PARAM SPRITE_PARAM(CLK, {SPR_EVAL_VCNT[0],SPR_EVAL_CNT}, SPRITE_PARAM_DATA, SPR_EVAL_RUN & SPR_EVAL_HIT & CE, {SPR_FETCH_LINE,SPR_FETCH_CNT}, SPR_LIST);
	
	bit          SPR_FETCH_LINE;
	bit          SPR_FETCH_RUN;
	bit  [ 7: 0] SPR_FETCH_CNT;
	bit  [ 3: 0] SPR_FETCH_TILE_X,SPR_FETCH_DOT_X;
	bit  [ 5: 0] SPR_FETCH_PAL1;
	bit          SPR_FETCH_FLIPX1;
	bit  [ 9: 0] SPR_FETCH_X;
	
	bit  [ 5: 0] SPR_FETCH_X1;
	bit  [ 2: 0] SPR_DRAW_DOT_NUM1;
	bit  [ 9: 0] SPR_DRAW_X1;
	bit          SPR_DRAW_SCRN1;
	bit          SPR_DRAW_FIRST1;
	bit          SPR_DRAW_LINE1;
	bit          SPR_LINE_FILL1;
	always @(posedge CLK or negedge RST_N) begin		
		bit  [ 3: 0] NEW_TILE_X,NEW_DOT_X;
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
			FETCH_X_MASK = 8'hFC;
			
			{NEW_TILE_X_OVF,NEW_TILE_X,NEW_DOT_X} = {1'b0,SPR_FETCH_TILE_X,SPR_FETCH_DOT_X} + 9'd1;
			FETCH_NEXT_WORD = ({SPR_FETCH_TILE_X,SPR_FETCH_DOT_X} & FETCH_X_MASK) != ({NEW_TILE_X,NEW_DOT_X} & FETCH_X_MASK);
			if (!BG_FETCH_EN) begin
				if (SPR_FETCH_RUN) begin
					if (!FETCH_NEXT_WORD || DOT_CE_R) begin
						{SPR_FETCH_TILE_X,SPR_FETCH_DOT_X} <= {NEW_TILE_X,NEW_DOT_X};
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
							{SPR_FETCH_TILE_X,SPR_FETCH_DOT_X} <= '0;
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
					SPR_FETCH_FLIPX1 <= SPR_LIST.FLIPX;
					SPR_FETCH_X1 <= SPR_FETCH_X[5:0];
					SPR_DRAW_DOT_NUM1 <= DRAW_DOT_NUM;
					SPR_DRAW_X1 <= SPR_LIST.X;
					SPR_DRAW_SCRN1 <= SPR_LIST.SCRN;
					SPR_DRAW_FIRST1 <= DRAW_FIRST;
					SPR_DRAW_LINE1 <= SPR_FETCH_LINE;
				end
				
				DRAW_DOT_NUM <= '0;
				if (HCNT == 9'h165 && (!VBLK || VCNT >= 9'h1FE)) begin
					SPR_FETCH_LINE = VCNT[0];
					SPR_FETCH_CNT <= '0;
					{SPR_FETCH_TILE_X,SPR_FETCH_DOT_X} <= '0;
					SPR_X <= '0;
					DRAW_FIRST <= 1;
					SPR_FETCH_RUN <= (SPR_EVAL_CNT != 9'd0);
				end
			end
			if (DOT_CE2) begin
				SPR_FETCH_X <= {SPR_FETCH_TILE_X,SPR_FETCH_DOT_X};
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
			RENDER_ROM_CYCLE <= 0;
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
				SPR_ROM_ADDR <= {TILE_N,DOT_Y,DOT_X[3:2]};
				RENDER_ROM_CYCLE <= SPR_FETCH_RUN;
			end
		end
	end
	
	//Cycle1
	bit  [31: 0] SPR_FETCH_PATT;
	bit  [ 5: 0] SPR_DRAW_PAL2;
	bit          SPR_DRAW_LINE2;
	bit  [ 5: 0] SPR_FETCH_X2;
	bit  [ 9: 0] SPR_LINE_X2;
	bit          SPR_DRAW_SCRN2;
	bit  [ 2: 0] SPR_DOT_NUM2;
	bit          SPR_LINE_FILL2;
	always @(posedge CLK or negedge RST_N) begin		
		bit  [ 5: 0] SPR_FETCH_X2_NEW;
		bit  [ 2: 0] LINE_PIX_CNT;
		bit  [ 9: 0] SPR_LINE_X2_NEW;
		
		if (!RST_N) begin
			SPR_FETCH_X2 <= '0;
			SPR_FETCH_PATT <= '0;
			SPR_LINE_FILL2 <= 0;
		end else if (EN) begin
			SPR_FETCH_X2_NEW = SPR_FETCH_X2 + 6'd1;
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
				SPR_FETCH_PATT <= SpriteDataFlip(ROM_D, SPR_FETCH_FLIPX1);
				SPR_FETCH_X2 <= SPR_FETCH_X1;
				SPR_DRAW_PAL2 <= SPR_FETCH_PAL1;
				SPR_LINE_FILL2 <= SPR_LINE_FILL1;
				SPR_DRAW_LINE2 <= SPR_DRAW_LINE1;
				SPR_DOT_NUM2 <= SPR_DRAW_DOT_NUM1;
				if (SPR_DRAW_FIRST1 && SPR_LINE_FILL1) SPR_LINE_X2 <= SPR_DRAW_X1;
				SPR_DRAW_SCRN2 <= SPR_DRAW_SCRN1;
				LINE_PIX_CNT <= '0;
			end
		end
	end
	
	//Cycle2
	bit  [ 7: 0] SPR_DRAW_PIX;
	always_comb begin
		case (SPR_FETCH_X2[1:0])
			2'h0: SPR_DRAW_PIX <= SPR_FETCH_PATT[31:24];
			2'h1: SPR_DRAW_PIX <= SPR_FETCH_PATT[23:16];
			2'h2: SPR_DRAW_PIX <= SPR_FETCH_PATT[15: 8];
			2'h3: SPR_DRAW_PIX <= SPR_FETCH_PATT[ 7: 0];
		endcase
	end
	wire         SPR_LINE_WREN = SPR_LINE_FILL2 & ~SPR_LINE_X2[9] & |SPR_DRAW_PIX;
	wire [20: 0] SPR_LINE_DIN = {7'b0000000,SPR_DRAW_PAL2,SPR_DRAW_PIX};
	
	bit  [20: 0] SPR_SCRN0_LINE_Q[2];
	wire [ 8: 0] SPR_SCRN0_LINE0_WA   = !SPR_DRAW_LINE2 ? SPR_LINE_X2[8:0] : DISP_X;
	wire [20: 0] SPR_SCRN0_LINE0_DATA = !SPR_DRAW_LINE2 ? SPR_LINE_DIN : 21'h0;
	wire         SPR_SCRN0_LINE0_WE   = !SPR_DRAW_LINE2 ? SPR_LINE_WREN & ~SPR_DRAW_SCRN2 : DOT_CE_R;
	PSH2_SPR_LINE SPR_SCRN0_LINE0(CLK, SPR_SCRN0_LINE0_WA, SPR_SCRN0_LINE0_DATA, SPR_SCRN0_LINE0_WE, DISP_X, SPR_SCRN0_LINE_Q[0]);
	
	wire [ 8: 0] SPR_SCRN0_LINE1_WA   =  SPR_DRAW_LINE2 ? SPR_LINE_X2[8:0] : DISP_X;
	wire [20: 0] SPR_SCRN0_LINE1_DATA =  SPR_DRAW_LINE2 ? SPR_LINE_DIN : 21'h0;
	wire         SPR_SCRN0_LINE1_WE   =  SPR_DRAW_LINE2 ? SPR_LINE_WREN & ~SPR_DRAW_SCRN2 : DOT_CE_R;
	PSH2_SPR_LINE SPR_SCRN0_LINE1(CLK, SPR_SCRN0_LINE1_WA, SPR_SCRN0_LINE1_DATA, SPR_SCRN0_LINE1_WE, DISP_X, SPR_SCRN0_LINE_Q[1]);
	
	wire [20: 0] SPR_SCRN0_LINE_DOUT = SPR_SCRN0_LINE_Q[~SPR_DRAW_LINE2];
	
	bit  [20: 0] SPR_SCRN1_LINE_Q[2];
	wire [ 8: 0] SPR_SCRN1_LINE0_WA   = !SPR_DRAW_LINE2 ? SPR_LINE_X2[8:0] : DISP_X;
	wire [20: 0] SPR_SCRN1_LINE0_DATA = !SPR_DRAW_LINE2 ? SPR_LINE_DIN : 21'h0;
	wire         SPR_SCRN1_LINE0_WE   = !SPR_DRAW_LINE2 ? SPR_LINE_WREN & SPR_DRAW_SCRN2 : DOT_CE_R;
	PSH2_SPR_LINE SPR_SCRN1_LINE0(CLK, SPR_SCRN1_LINE0_WA, SPR_SCRN1_LINE0_DATA, SPR_SCRN1_LINE0_WE, DISP_X, SPR_SCRN1_LINE_Q[0]);
	
	wire [ 8: 0] SPR_SCRN1_LINE1_WA   =  SPR_DRAW_LINE2 ? SPR_LINE_X2[8:0] : DISP_X;
	wire [20: 0] SPR_SCRN1_LINE1_DATA =  SPR_DRAW_LINE2 ? SPR_LINE_DIN : 21'h0;
	wire         SPR_SCRN1_LINE1_WE   =  SPR_DRAW_LINE2 ? SPR_LINE_WREN & SPR_DRAW_SCRN2 : DOT_CE_R;
	PSH2_SPR_LINE SPR_SCRN1_LINE1(CLK, SPR_SCRN1_LINE1_WA, SPR_SCRN1_LINE1_DATA, SPR_SCRN1_LINE1_WE, DISP_X, SPR_SCRN1_LINE_Q[1]);
	
	wire [20: 0] SPR_SCRN1_LINE_DOUT = SPR_SCRN1_LINE_Q[~SPR_DRAW_LINE2];
	
	
	assign BG_FETCH_EN = 00;
	
	assign ROM_ADDR = SPR_ROM_ADDR;
	assign RENDER_SRAM_CYCLE = (SPR_LOAD_RUN && SPR_LOAD_STATE != 3'h5);
	
	//Cycle4
	bit  [ 7: 0] SPR_OUT_PIX[2];
	bit  [ 5: 0] SPR_OUT_PAL[2];	
	always @(posedge CLK or negedge RST_N) begin	
		if (!RST_N) begin
			
		end else if (EN) begin		
			if (DOT_CE_R) begin
				{SPR_OUT_PAL[0],SPR_OUT_PIX[0]} <= SPR_SCRN0_LINE_DOUT[13:0];
				{SPR_OUT_PAL[1],SPR_OUT_PIX[1]} <= SPR_SCRN1_LINE_DOUT[13:0];
			end
		end
	end
	
	bit  [10: 0] BG_COLOR[2];
	always_comb begin
		BG_COLOR[0] <= {SPR_OUT_PAL[0],5'b00000} + {3'b000,SPR_OUT_PIX[0]};
		BG_COLOR[1] <= {SPR_OUT_PAL[1],5'b00000} + {3'b000,SPR_OUT_PIX[1]};
	end
	
	bit  [23: 0] OUT_RGB[2];
	always @(posedge CLK or negedge RST_N) begin
		bit  [23: 0] PAL[2];
	
		if (!RST_N) begin
			OUT_RGB <= '{2{'0}};
		end else if (EN) begin
			if (CE) begin
				case (DOTCLK_DIV)
					2'b00: PAL[0] <= PAL_Q;
					2'b10: PAL[1] <= PAL_Q;
				endcase
			end
			
			if (DOT_CE_R) begin
				if (SPR_OUT_PIX[0])
					OUT_RGB[0] <= PAL[0];
				else
					OUT_RGB[0] <= SCREEN_BG_COL[0];
					
				if (SPR_OUT_PIX[1])
					OUT_RGB[1] <= PAL[1];
				else
					OUT_RGB[1] <= SCREEN_BG_COL[1];
			end
		end
	end
	assign {R,G,B} = RGBBright(OUT_RGB[DOTCLK_DIV[1]], 8'h80 - (SCREEN_BRIGHT[DOTCLK_DIV[1]] & 8'h7F));
	
`ifdef DEBUG
	assign DBG_REGS = VREGS[0]^VREGS[1]^VREGS[2]^VREGS[3]^SREGS[0]^SREGS[1]^SREGS[2]^SREGS[3];
	assign DBG_SPR_ADDR = {SPR_ADDR,1'b0};
	assign DBG_ROM_ADDR = {ROM_A,2'b00};
	assign DBG_SPR_LIST = SPR_LIST;
`endif
	
endmodule
