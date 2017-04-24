//Assignment 3
//EE480 Spring 2017
//Griffin Urton, Baiyoke Nateesuwan, Jong Yeu Wu

// standard sizes
`define ARRAY		[1:0]
`define STATE		[4:0]
`define OP		[4:0]
`define WORD		[15:0]
`define HALFWORD	[7:0]
`define REGSIZE		[511:0]   
`define MEMSIZE		[65035:0]
`define Opcode		[15:12]
`define Immed		[11:0]
`define PREFIX		[3:0]

// initial states
`define Start	5'b11111
`define GetOp   5'b11110

// opcode values/ state numbers
`define NOimmed 4'b0000
`define OPget 4'b0001
`define OPpop 4'b0010
`define OPput 4'b0011
`define OPcall 4'b0100
`define OPjumpf 4'b0101
`define OPjump 4'b0110
`define OPjumpt 4'b0111
`define OPpre 4'b1000
`define OPpush 4'b1001

// secondary opcode field values
`define OPadd 12'h0001
`define OPand 12'h0002
`define OPdup 12'h0003
`define OPload 12'h0004
`define OPlt 12'h0005
`define OPor 12'h0006
`define OPret 12'h0007
`define OPstore 12'h0008
`define OPsub 12'h0009
`define OPsys 12'h000A
`define OPtest 12'h000B
`define OPxor 12'h000C



module decode(sp, dest, src, prefix, preEmpty, isJump, preFlag, ir);
output reg `HALFWORD sp;
output reg `WORD dest;
output reg `WORD src;
output reg `PREFIX prefix;
output reg isJump;
output reg preEmpty;
input preFlag;
input `WORD ir;

always @(ir) begin
  case (ir `Opcode)
  		`NOimmed: begin
		case(ir `Immed)
	  		`OPadd: begin
					dest = sp - 1;
					src = sp;
					sp = sp - 1;
			end
		
			`OPand: begin
					dest = sp - 1;
					src = sp;
					sp = sp - 1;
			end
			
			`OPdup: begin
					dest = sp + 1;
					src = sp;
					sp = sp + 1;
			end
		
			`OPload: begin
					dest = sp;
			end
		
			`OPlt: begin
					dest = sp - 1;
					src = sp;
					sp = sp - 1;
			end
		
			`OPor: begin
					dest = sp - 1;
					src = sp;
					sp = sp - 1;
			end
		
			`OPret: begin
					src = sp;
					sp = sp - 1;
			end
		
			`OPstore: begin
					dest = sp - 1;
					src = sp;
					sp = sp - 1;
			end
		
			`OPsub: begin
					dest = sp - 1;
					src = sp;
					sp = sp - 1;
			end
		
		
			`OPtest: begin
					src = sp;
					sp = sp - 1;
			end
		
			`OPxor: begin
					dest = sp - 1;
					src = sp;
					sp = sp - 1;
			end	
		endcase
	end
	
    `OPget: begin 
    		dest = sp + 1;
		src = sp - ir `Immed;
		sp = sp + 1;
	end

    `OPpop: begin 
    		sp = sp - ir `Immed;
	end

    `OPput: begin 
    		dest = sp - ir `Immed;
		src = sp;
	end


    `OPcall: begin
		dest = sp + 1;
		sp = sp + 1;
		isJump = 1;
	end
   

    `OPpre: begin
		prefix = ir[3:0];
		preEmpty = 0;
	end

    `OPpush: begin
   		 dest = sp + 1;
		 sp = sp + 1;
   	 end

	`OPjumpf: begin isJump = 1; end
	`OPjump: begin isJump = 1; end
	`OPjumpt: begin isJump = 1; end
endcase


preEmpty = (preFlag ? 1 : 0);
end
endmodule

//ALU
module alu(result, op, in1, in2);
output reg `WORD result;
input wire `Immed op;
input wire `WORD in1; 
input wire `WORD in2;

always @(op) begin
  case (op) // in1 = dest_value, in2 = src_value
    `OPadd: begin result = in1 + in2; $display("Add"); end
    `OPand: begin result = in1 & in2; end
    `OPdup: begin result = in2; end
    //`OPload: begin result = mainmem[in1]; end
    `OPlt: begin result = (in1 < in2); end
    `OPor: begin result = in1 | in2; end
    `OPsub: begin result = in1 - in2; end
    `OPxor: begin result = in1 ^ in2; end
    default: begin result = in1; end
  endcase
end
endmodule

module processor(halted, reset, clk); // operator input removed
output reg halted;
input clk;
input reset;	
reg `WORD regfile `REGSIZE;
reg `WORD mainmem `MEMSIZE;

    

reg `HALFWORD sp `ARRAY;
wire `HALFWORD sp_wire;
reg `WORD pc `ARRAY;
reg `WORD new_pc `ARRAY;
reg `WORD dest `ARRAY; 
reg `WORD result_reg;
wire `WORD dest_wire;
reg `WORD src `ARRAY;
wire `WORD src_wire;
reg `WORD dest_value `ARRAY;
reg `WORD src_value `ARRAY;
wire `WORD result_value;
reg `PREFIX prefix `ARRAY;
wire `PREFIX prefix_wire;
reg `WORD ir `ARRAY;   	// Register that holds instruction spec code
reg torf `ARRAY;       	// True or false register
reg preEmpty `ARRAY;	// Register describing the state of pre (loaded = 0, not loaded = 1)
wire preEmpty_wire;
reg preFlag `ARRAY; 	// Flag used to alert preEmpty owner that pre needs to be written
reg writeFlag `ARRAY;	// Flag to determine whether to write to the stack or not
reg thread;
wire isJump;
reg loadFlag;
reg halt `ARRAY;


always @ (reset) begin
	pc[0] = 0;
	pc[1] = 1;
	halt[0] = 0;
	halt[1] = 0;
	sp[0] = 0;
	sp[1] = 256;
//sp_wire = 0;
	preEmpty[0] = 1;
	preEmpty[1] = 1;
	writeFlag[0] = 1;
	writeFlag[1] = 1;
loadFlag = 0;
thread = 0;
	$readmemh1(mainmem);
end

always@(*) begin halted = halt[1] & halt[0]; end

// Toggle thread each clock cycle
always@(posedge clk) thread <= !thread;

always @(*) begin 
	sp[thread] = sp_wire;
	dest[thread] = dest_wire;
	src[thread] = src_wire;
	prefix[thread] = prefix_wire;
	preEmpty[thread] = preEmpty_wire;
end

decode mydecode(sp_wire, dest_wire, src_wire, prefix_wire, preEmpty_wire, isJump, preFlag[thread], ir[thread]);

always @(posedge clk) begin ir[thread] = mainmem[pc[thread]]; $display("%h",ir[0]);$display("%h",ir[1]);
pc[thread] = (isJump ? new_pc[thread] : pc[thread] + 2);
end

always @(posedge clk) begin
	dest_value[thread] = regfile[dest[thread]];
	//regfile[thread ? dest[thread] + 256: dest[thread]];
	src_value[thread] = regfile[dest[thread]];
	//regfile[thread ? src[thread] + 256 : src[thread]];
end

alu stackALU(result_value, ir[thread] `Immed, dest_value[thread], src_value[thread]);

always @(posedge clk) begin

case (ir[thread] `Opcode)
   	 
	`NOimmed: begin
   	case (ir[thread] `Immed)
		 `OPload: begin result_reg <= mainmem[dest_value[thread]]; writeFlag[thread] = 0; loadFlag = 1; $display("load");
$display("PC0 PC1 %h %h", pc[0], pc[1]);$display("Reg %h", result_reg); pc[thread] = pc[thread] + 2; end
		 
   		`OPret: begin pc[thread] = src_value[thread]; writeFlag[thread] = 0; pc[thread] = pc[thread] + 2; end

   		`OPstore: begin mainmem[dest_value[thread]] = src_value[thread]; writeFlag[thread] = 0; pc[thread] = pc[thread] + 2; end

   		`OPsys: begin $display("Sys instruction"); halt[thread] = 1; writeFlag[thread] = 0; pc[thread] = pc[thread] + 2; end
			
		`OPtest: begin torf[thread] = (src_value[thread] ? 1 : 0); writeFlag[thread] = 0; pc[thread] = pc[thread] + 2; end
		
		default: writeFlag[thread] = 1;
			
   	endcase
	dest_value[thread] = loadFlag ? result_reg : result_value;
    	end
   	 
    //With `Immed

	//GET:  d=sp+1; s=sp-unsigned(immed12); ++sp; reg[d]=reg[s]
	`OPget: begin 
    		if(!halt[thread]) begin
    			dest_value[thread] = src_value[thread];
		end
	end

	//PUT: d=sp-unsigned(immed12); s=sp; reg[d]=reg[s]
	`OPput: begin 
		if(!halt[thread]) begin
		dest_value[thread] = src_value[thread];
		end
	end

	//CALL:  d=sp+1; ++sp; reg[d]=pc+1; pc=prefix({(pc>>12), immed12})
	`OPcall: begin
		if(!halt[thread]) begin
			dest_value[thread] = pc[thread] + 1;
			if(!preEmpty[thread]) begin
		   		new_pc[thread] = {prefix[thread], ir[thread] `Immed};
		   		preFlag[thread] = 1;
   	 		end
    			else begin new_pc[thread] = ir[thread] `Immed; end
		end
$display("Call %d", new_pc[thread]);
	end

	//JUMPF: if (!torf) pc=prefix({(pc>>12), immed12});
	`OPjumpf: begin
		if(!halt[thread]) begin
			writeFlag[thread] = 0;
    			if(!torf[thread]) begin
   	 			if(!preEmpty[thread]) begin
   					new_pc[thread] = {prefix[thread], ir[thread] `Immed}; 
   					preFlag[thread] = 1;
    				end
    				else begin
        				new_pc[thread] = ir[thread] `Immed;
    				end
    			end
$display("JumpF to %d", new_pc[thread]);
    		end
	end


	//JUMP: pc=prefix({(pc>>12), immed12})
	`OPjump: begin
		if(!halt[thread]) begin
			writeFlag[thread] = 0;
			if(!preEmpty[thread]) begin
   				new_pc[thread] = {prefix[thread], ir[thread] `Immed};
   				preFlag[thread] = 1;
			end
			else begin
    			new_pc[thread] = ir[thread] `Immed;
			end
		end
$display("Jump to %d", new_pc[thread]);
	end


	//JUMPT: if (torf) pc=prefix({(pc>>12), immed12})
	`OPjumpt: begin
		if(!halt[thread]) begin
			writeFlag[thread] = 0;
			if(torf[thread]) begin
				if(!preEmpty[thread]) begin
				new_pc[thread] = {prefix[thread], ir[thread] `Immed};
				preFlag[thread] = 1;
        			end
			end
    			else begin
        			new_pc[thread] = ir[thread] `Immed;
        		end
		end
	end

	//PUSH: d=sp+1; ++sp; reg[d]=prefix(sign_extend(immed12));
	`OPpush: begin
		if(!halt[thread]) begin
			prefix[thread] = (ir[thread][11] ? 4'b1111 : 4'b0000);
			dest_value[thread] = {prefix[thread], ir[thread] `Immed};
		end
   	 end
	 
	 default: begin writeFlag[thread] = 0; end
endcase

end
always @(posedge clk)
if(!halt[thread] && writeFlag[thread]) regfile[dest[thread]] = dest_value[thread];
//regfile[thread ? dest[thread] + 256 : dest[thread]] = dest_value[thread];
endmodule // processor

     
module testbench;
	reg reset = 0;
	reg clk = 0;
	wire halted;
integer count = 0;
	processor PE(halted, reset, clk);
	initial begin
  	$dumpfile;
  	$dumpvars(0, PE);
  	#10 reset = 1;
  	#10 reset = 0;
  	while (!halted) begin
    	#10 clk = 1;
   	#10 clk = 0;
count = count + 1;
 	end
  	$finish;
	end
endmodule
