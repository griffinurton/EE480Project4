// basic sizes of things
`define WORD	[15:0]
`define Opcode	[15:12]
`define Immed	[11:0]
`define STATE	[7:0]
`define PRE	[3:0]
`define REGSIZE	[255:0]
`define REGNUM	[7:0]
`define MEMSIZE [65535:0]

// opcode values hacked into state numbers
`define OPAdd	{4'h0, 4'h0}
`define OPSub	{4'h0, 4'h1}
`define OPTest	{4'h0, 4'h2}
`define OPLt	{4'h0, 4'h3}

`define OPDup	{4'h0, 4'h4}
`define OPAnd	{4'h0, 4'h5}
`define OPOr	{4'h0, 4'h6}
`define OPXor	{4'h0, 4'h7}

`define OPLoad	{4'h0, 4'h8}
`define OPStore	{4'h0, 4'h9}

`define OPRet	{4'h0, 4'ha}
`define OPSys	{4'h0, 4'hb}

`define OPPush	{4'h1, 4'h0}

`define OPCall	{4'h4, 4'h0}
`define OPJump	{4'h5, 4'h0}
`define OPJumpF	{4'h6, 4'h0}
`define OPJumpT	{4'h7, 4'h0}

`define OPGet	{4'h8, 4'h0}
`define OPPut	{4'h9, 4'h0}
`define OPPop	{4'ha, 4'h0}
`define OPPre	{4'hb, 4'h0}

`define	Start	{4'hf, 4'hf}
`define	Start1	{4'hf, 4'he}


module processor(halt, reset, clk);
output reg halt;
input reset, clk;

reg `WORD r `REGSIZE;
reg `WORD m `MEMSIZE;
reg `WORD pc = 0;
reg `WORD ir;
reg `STATE sn = `Start;
reg `REGNUM sp = -1;
reg `REGNUM d;
reg `REGNUM s;
reg torf;
reg preit = 0;
reg `PRE pre;
integer a;

always @(reset) begin
  halt = 0;
  pc = 0;
  sn <= `Start;
  $readmemh0(r);
  $readmemh1(m);
end

always @(posedge clk) begin
  case (sn)
    `Start: begin ir <= m[pc]; sn <= `Start1; end
    `Start1: begin
             pc <= pc + 1;            // bump pc
	     sn <= {(ir `Opcode), (((ir `Opcode) == 0) ? ir[3:0] : 4'd0)};
	    end

    `OPAdd: begin d=sp-1; s=sp; sp=sp-1; r[d]=r[d]+r[s]; sn<=`Start; end
    `OPSub: begin d=sp-1; s=sp; sp=sp-1; r[d]=r[d]-r[s]; sn<=`Start; end
    `OPTest: begin s=sp; sp=sp-1; torf=(r[s]!=0); sn<=`Start; end
    `OPLt: begin d=sp-1; s=sp; sp=sp-1; r[d]=(r[d]<r[s]); sn<=`Start; end

    `OPDup: begin d=sp+1; s=sp; sp=sp+1; r[d]=r[s]; sn<=`Start; end
    `OPAnd: begin d=sp-1; s=sp; sp=sp-1; r[d]=(r[d]&r[s]); sn<=`Start; end
    `OPOr: begin d=sp-1; s=sp; sp=sp-1; r[d]=(r[d]|r[s]); sn<=`Start; end
    `OPXor: begin d=sp-1; s=sp; sp=sp-1; r[d]=(r[d]^r[s]); sn<=`Start; end

    `OPLoad: begin d=sp; r[d]=m[r[d]]; sn<=`Start; end
    `OPStore: begin d=sp-1; s=sp; sp=sp-1; m[r[d]]=r[s]; r[d]=r[s]; sn<=`Start; end

    `OPRet: begin s=sp; sp=sp-1; pc=r[s]; sn<=`Start; end

    `OPPush: begin d=sp+1; sp=sp+1; r[d]={(preit ? pre : {4{ir[11]}}), ir `Immed}; preit=0; sn<=`Start; end

    `OPCall: begin d=sp+1; sp=sp+1; r[d]=pc; pc={(preit ? pre : pc[15:12]), ir `Immed}; preit=0; sn<=`Start; end
    `OPJump: begin pc={(preit ? pre : pc[15:12]), ir `Immed}; preit=0; sn<=`Start; end
    `OPJumpF: begin if (!torf) pc={(preit ? pre : pc[15:12]), ir `Immed}; preit=0; sn<=`Start; end
    `OPJumpT: begin if (torf) pc={(preit ? pre : pc[15:12]), ir `Immed}; preit=0; sn<=`Start; end

    `OPGet: begin d=sp+1; s=sp-(ir `REGNUM); sp=sp+1; r[d]=r[s]; sn<=`Start; end
    `OPPut: begin d=sp-(ir `REGNUM); s=sp; r[d]=r[s]; sn<=`Start; end
    `OPPop: begin sp=sp-(ir `REGNUM); sn<=`Start; end
    `OPPre: begin pre=(ir `PRE); preit=1; sn<=`Start; end

    default: begin halt<=1; sn<=`Start; end
  endcase
end
endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule