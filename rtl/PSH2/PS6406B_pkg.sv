package PS6406B_PKG; 

	//Register
	typedef struct packed		//W;5FFE0
	{
		bit [ 7: 0] ALPHA0;
		bit [ 7: 0] ALPHA1;
		bit [ 7: 0] ALPHA2;
		bit [ 7: 0] ALPHA3;
	} REG0_t;
	parameter bit [31:0] REG0_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] REG0_INIT = 32'h00000000;
	
	typedef struct packed		//W;5FFE4
	{
		bit [ 7: 0] ALPHA4;
		bit [ 7: 0] ALPHA5;
		bit [ 7: 0] ALPHA6;
		bit [ 7: 0] ALPHA7;
	} REG1_t;
	parameter bit [31:0] REG1_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] REG1_INIT = 32'h00000000;
	
	typedef struct packed		//W;5FFE8
	{
		bit [ 3: 0] S0PRI;
		bit [ 3: 0] S1PRI;
		bit [ 3: 0] S2PRI;
		bit [ 3: 0] S3PRI;
		bit [ 7: 0] UNKNOWN1;
		bit [ 3: 0] UNKNOWN0;
		bit [ 3: 0] POSTPRI;
	} REG2_t;
	parameter bit [31:0] REG2_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] REG2_INIT = 32'h00000000;
	
	typedef struct packed		//W;5FFF8
	{
		bit         BG0MODE;
		bit [ 1: 0] UNUSED3;
		bit [ 4: 0] BG0BANK;
		bit         BG1MODE;
		bit [ 1: 0] UNUSED2;
		bit [ 4: 0] BG1BANK;
		bit         BG2MODE;
		bit [ 1: 0] UNUSED1;
		bit [ 4: 0] BG2BANK;
		bit         BG3MODE;
		bit [ 1: 0] UNUSED0;
		bit [ 4: 0] BG3BANK;
	} REG6_t;
	parameter bit [31:0] REG6_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] REG6_INIT = 32'h00000000;
	
	typedef struct packed		//W;5FFFC
	{
		bit [ 2: 0] UNUSED1;
		bit [ 4: 0] LINEBANK;
		bit [ 7: 0] UNUSED0;
		bit [ 3: 0] BG0CTRL;
		bit [ 3: 0] BG1CTRL;
		bit [ 3: 0] BG2CTRL;
		bit [ 3: 0] BG3CTRL;
	} REG7_t;
	parameter bit [31:0] REG7_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] REG7_INIT = 32'h00000000;

	//Background
	typedef enum {
		BGRAM_EMPTY,
		BGRAM_PRECOL,
		BGRAM_POSTCOL, 
		BGRAM_SCROLL,
		BGRAM_ATTR,
		BGRAM_TILE
	} BGRAMSlot_t;
	
	typedef struct packed
	{
		bit [ 6: 0] UNUSED1;
		bit [ 8: 0] Y;
		bit [ 6: 0] UNUSED0;
		bit [ 8: 0] X;
	} BGScroll_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED1;
		bit [ 2: 0] PRI;
		bit [ 7: 0] ZOOM;
		bit [ 7: 0] ALPHA;
		bit [ 7: 0] BANK;
	} BGAttr_t;
	
	typedef struct packed
	{
		bit [ 7: 0] PAL;
		bit [ 4: 0] UNUSED;
		bit [18: 0] NUM;
	} BGTile_t;
	
	typedef struct
	{
		BGScroll_t  SCROLL;
		BGAttr_t    ATTR;
		BGTile_t    TILE[2];
	} BG_t;
	parameter BG_t BG_INIT = '{32'h00000000,32'h00000000,'{32'h00000000,32'h00000000}};
	
	function bit [7:0] ColorBlend(input bit [7:0] CA, input bit [7:0] CB, input bit [7:0] RA, input bit [7:0] RB);
		bit [15:0] S;
		
		S = (CA * RA) + (CB * RB);
		return S[15:8]; 
	endfunction
	
	function [23:0] RGBBlend(input bit [23:0] CFST, input bit [23:0] CSEC, input bit [7:0] ALPHA);
		bit [7:0] R,G,B;
		
		R = ColorBlend(CFST[23:16], CSEC[23:16], {1'b0,ALPHA}+1, {1'b0,~ALPHA});
		G = ColorBlend(CFST[15: 8], CSEC[15: 8], {1'b0,ALPHA}+1, {1'b0,~ALPHA});
		B = ColorBlend(CFST[ 7: 0], CSEC[ 7: 0], {1'b0,ALPHA}+1, {1'b0,~ALPHA});
		
		return {R,G,B};
	endfunction
	
	//Sprite
	typedef struct packed
	{
		bit [ 5: 0] UNUSED4;
		bit [ 9: 0] Y;
		bit [ 5: 0] UNUSED3;
		bit [ 9: 0] X;
		bit         FLIPY;
		bit         UNUSED2;
		bit [ 1: 0] SP;
		bit [ 3: 0] H;
		bit [ 7: 0] ZOOMY;
		bit         FLIPX;
		bit         UNUSED1;
		bit [ 1: 0] PRI;
		bit [ 3: 0] W;
		bit [ 7: 0] ZOOMX;
		bit [ 7: 0] PAL;
		bit         BPP;
		bit [ 2: 0] A;
		bit         UNUSED0;
		bit [18: 0] TN;
	} Sprite_t;
	
	typedef struct packed
	{
		bit [ 7: 0] Y;
		bit [ 3: 0] H;
		bit         FLIPY;
		bit [ 9: 0] X;
		bit [ 3: 0] W;
		bit         FLIPX;
		bit [15: 0] ZOOMX;
		bit         BPP;
		bit [ 7: 0] PAL;
		bit [ 1: 0] PRI;
		bit [ 2: 0] A;
		bit [18: 0] TN;
	} SpriteFetch_t;
	
	function bit [31:0] SpriteDataFlip(input bit [31:0] DATA, input bit FLIP, input bit BPP);
		return !FLIP ? DATA : (!BPP ? {DATA[3:0],DATA[7:4],DATA[11:8],DATA[15:12],DATA[19:16],DATA[23:20],DATA[27:24],DATA[31:28]} : {DATA[7:0],DATA[15:8],DATA[23:16],DATA[31:24]}); 
	endfunction
	
endpackage
