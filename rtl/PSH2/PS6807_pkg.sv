package PS6807_PKG; 
	
	function bit [7:0] ColorBright(input bit [7:0] C, input bit [7:0] BR);
		bit [14:0] S;
		
		S = (C * BR);
		return S[14:7]; 
	endfunction
	
	function [23:0] RGBBright(input bit [23:0] C, input bit [7:0] BR);
		bit [7:0] R,G,B;
		
		R = ColorBright(C[23:16], BR);
		G = ColorBright(C[15: 8], BR);
		B = ColorBright(C[ 7: 0], BR);
		
		return {R,G,B};
	endfunction
	
	//Sprite
	typedef struct packed
	{
		bit [ 3: 0] H;
		bit [ 1: 0] UNUSED2;
		bit [ 9: 0] Y;
		bit [ 3: 0] W;
		bit [ 1: 0] UNUSED1;
		bit [ 9: 0] X;
		bit         FLIPY;
		bit         FLIPX;
		bit [ 5: 0] PAL;
		bit [ 4: 0] UNUSED0;
		bit [18: 0] TN;
	} Sprite4_t;
	
	typedef struct packed
	{
		bit         SCRN;
		bit [ 3: 0] H;
		bit [ 7: 0] Y;
		bit [ 3: 0] W;
		bit [ 9: 0] X;
		bit         FLIPY;
		bit         FLIPX;
		bit [ 5: 0] PAL;
		bit [18: 0] TN;
	} SpriteFetch_t;
	
	function bit [31:0] SpriteDataFlip(input bit [31:0] DATA, input bit FLIP);
		return !FLIP ? DATA : {DATA[7:0],DATA[15:8],DATA[23:16],DATA[31:24]}; 
	endfunction
	
endpackage
