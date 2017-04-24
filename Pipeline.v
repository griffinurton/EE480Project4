// basic sizes of things
`define WORD	 [15:0]
`define Opcode [15:12]
`define OP     [3:0]
`define Immed	 [11:0]
`define STATE	 [7:0]
`define PRE	   [3:0]
//Double reg size
`define REGSIZE	[511:0]
`define REGNUM	[7:0]
`define MEMSIZE [65535:0]
`define THREAD  [1:0]

// opcode values hacked into state numbers
`define OPAdd	 {4'h0, 4'h0}
`define OPSub	 {4'h0, 4'h1}
`define OPTest {4'h0, 4'h2}
`define OPLt	 {4'h0, 4'h3}

`define OPDup	{4'h0, 4'h4}
`define OPAnd	{4'h0, 4'h5}
`define OPOr	{4'h0, 4'h6}
`define OPXor	{4'h0, 4'h7}

`define OPLoad	{4'h0, 4'h8}
`define OPStore	{4'h0, 4'h9}

`define OPRet	{4'h0, 4'ha}
`define OPSys	{4'h0, 4'hb}
`define OPnop	{4'h0, 4'hc}

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


module decode(opout, immed, ir);
  output reg `Opcode opout;
  output reg `Immed immed;

  input `WORD ir;

  always @(ir) begin
    opout <= {(ir `Opcode), (((ir `Opcode) == 0) ? ir[3:0] : 4'd0)};
    immed <= ir `Immed;
  end
endmodule

module alu(result, op, in1, in2);
  output reg `WORD result;
  input wire `Opcode op;
  input wire `WORD in1, in2;

  always @(op, in1, in2) begin
    case (op)
        `OPAdd: begin result=in1+in2; end
        `OPSub: begin result=in1-in2; end
        `OPLt: begin result=(in1<in2); end
        `OPDup: begin result=in2; end
        `OPAnd: begin result=(in1&in2); end
        `OPOr: begin result=(in1|in2); end
        `OPXor: begin result=(in1^in2); end
      default: begin result = in1; end
    endcase
  end
endmodule

module processor(halted, reset, clk);
  output reg halted;
  input reset, clk;

  reg `WORD regfile `REGSIZE;
  reg `WORD mainmem `MEMSIZE;
  reg `WORD ir;
  reg `WORD newpc `THREAD;
  wire `OP op;
  wire `Immed immed;
  wire `WORD result;
  reg  `WORD in1;
  reg  `WORD in2;
  reg  `OP aluop;

  reg `OP s0op `THREAD;
  reg `OP s1op `THREAD;
  reg `OP s2op `THREAD;
  reg `OP s3op `THREAD;
  reg `WORD s0pc `THREAD;
  reg `WORD s1pc `THREAD;
  reg `WORD s2pc `THREAD;
  reg `WORD pc `THREAD;
  reg `REGNUM sp `THREAD;
  reg `WORD s0immed `THREAD;
  reg `WORD s1immed `THREAD;
  reg `WORD s2immed `THREAD;
  reg preit `THREAD;
  reg `PRE pre `THREAD;	//added initializations for pre0, pre1,
  reg torf `THREAD;	//torf0, and torf1
  reg halt `THREAD;
  reg `WORD s2inone `THREAD;
  reg `WORD s2intwo `THREAD;
  reg `WORD s3inone `THREAD;
  reg `WORD s3intwo `THREAD;
  reg `REGNUM s2sp `THREAD;
  reg `REGNUM dest `THREAD;
  reg even;
  reg odd;

  always @(reset) begin
    halt[0] = 0;
    halt[1] = 0;
    pc[0] = 0;
    pc[1] = 1;	// starting the second pc at approximately half of MEMSIZE
    sp[0] = 0;
    sp[1] = 255;
    preit[0] = 0;
    preit[1] = 0;
    torf[0] = 0;
    torf[1] = 1;
    s0op[0] = `OPnop;
    s1op[0] = `OPnop;
    s2op[0] = `OPnop;
    s3op[0] = `OPnop;
    s0op[1] = `OPnop;
    s1op[1] = `OPnop;
    s2op[1] = `OPnop;
    s3op[1] = `OPnop;
    $readmemh0(regfile);
    $readmemh1(mainmem);
  end

  always @(*) even = clk;
  always @(*) odd = !clk;

  decode mydecode(op, immed, ir);
  alu myalu(result, aluop, in1, in2);

  always @(*) ir = mainmem[pc[even]];
  // new pc value
  always @(*) newpc[even] = (((s2op[even] == `OPJump) || (s2op[even] == `OPRet) || (s2op[even] == `OPCall) || (torf[even] && (s2op[even] == `OPJumpT)) || (!torf[even] && (s2op[even] == `OPJumpF))) ? s2immed[even] : (s0pc[even]));
  //HALT test
  always @(*) halted = (halt[0]&&halt[1]);



  //STAGE ONE (EVEN)
  // Instruction Fetch
  always @(posedge clk) begin
    // Jump if set
    s0pc[even] <= newpc[even];
    // grab opcode
    s0op[even] <= (halt[even] ? `OPnop : op);
    // grab immed
    s0immed[even] <= (halt[even] ? 0 : immed);
    // increment to next opcode
    s0pc[even] <= s0pc[even] + 1;
  end



  //STAGE TWO (ODD)
  // Decode
  always @(posedge clk) begin
    s1op[odd] <= (halt[odd] ? `OPnop : s0op[odd]);
    s1immed[odd] <= s0immed[odd];
    s1pc[odd] <= s0pc[odd];
    case (s1op[odd])
      `OPPush: begin s1immed[odd]<={(preit[odd] ? pre[odd] : 4'b0000), s1immed[odd]}; preit[odd]=0; end
      `OPCall: begin s1immed[odd]<={(preit[odd] ? pre[odd] : 4'b0000), s1immed[odd]}; preit[odd]=0; end
      `OPJump: begin s1immed[odd]<={(preit[odd] ? pre[odd] : 4'b0000), s1immed[odd]}; preit[odd]=0; end
      `OPJumpF: begin s1immed[odd]<={(preit[odd] ? pre[odd] : 4'b0000), s1immed[odd]}; preit[odd]=0; end
      `OPJumpT: begin s1immed[odd]<={(preit[odd] ? pre[odd] : 4'b0000), s1immed[odd]}; preit[odd]=0; end
      default: s1immed[odd] <= (halt[odd] ? 0 : s1immed[odd]);
    endcase
  end



  //STAGE THREE (EVEN)
  // Register File
  always @(posedge clk) begin
    s2op[even] <= (halt[even] ? `OPnop : s1op[even]);
    s2immed[even] <= s1immed[even];
    // Setting d(s2inone0) and s(s2intwo0)
    if (s2op[even] == `OPAdd || s2op[even] == `OPAnd || s2op[even] == `OPLt || s2op[even] == `OPOr || s2op[even] == `OPStore || s2op[even] == `OPSub || s2op[even] == `OPXor) begin
      s2inone[even] <= regfile[sp[even] - 1];
      s2sp[even] <= sp[even] - 1;
      s2intwo[even] <= regfile[sp[even]];
    end
    else if (s2op[even] == `OPDup) begin
      s2inone[even] <= regfile[sp[even] + 1];
      s2sp[even] <= sp[even] + 1;
      s2intwo[even] <= regfile[sp[even]];
    end
    else if (s2op[even] == `OPGet) begin
      s2inone[even] <= regfile[sp[even]+1];
      s2sp[even] <= sp[even] + 1;
      s2intwo[even] <= regfile[sp[even]-(s2immed[even])];
    end
    else if (s2op[even] == `OPLoad) begin
      s2inone[even] <= regfile[sp[even]];
      s2sp[even] <= sp[even];
    end
    else if (s2op[even] == `OPPut) begin
      s2inone[even] <= regfile[sp[even]-(s2immed[even])];
      s2sp[even] <= sp[even]-(s2immed[even]);
      s2intwo[even] <= regfile[sp[even]];
    end
    else if (s2op[even] == `OPCall) begin
      s2inone[even] <= s1pc[even];
      s2sp[even] <= sp[even] + 1;
    end
    else if (s2op[even] == `OPPush) begin
      s2inone[even] <= s2immed[even];
      s2sp[even] <= sp[even] + 1;
    end
    else if (s2op[even] == `OPTest) begin
      torf[even] <= regfile[sp[even]] != 0;
    end
    else if (s2op[even] == `OPRet) begin
      s2immed[even] <= regfile[sp[even]];
    end
    else if (s2op[even] == `OPSys) begin
      halt[even] <= 1;
    end
    // Incremeting or decrementing SP0
    if (s2op[even] == `OPAdd || s2op[even] == `OPAnd || s2op[even] == `OPLt || s2op[even] == `OPOr || s2op[even] == `OPRet || s2op[even] == `OPStore || s2op[even] == `OPSub || s2op[even] == `OPTest || s2op[even] == `OPXor) begin
     // decrement sp by 1
     sp[even] <= sp[even] - 1;
    end
    else if (s2op[even] == `OPCall || s2op[even] == `OPDup || s2op[even] == `OPGet || s2op[even] == `OPPush) begin
     // increment sp by 1
     sp[even] <= sp[even] + 1;
    end
    else if (s2op[even] == `OPPop) begin
      //(sets sp=0 if unsigned(immed12)>sp)
      if (even) begin
        if (((s2immed[1])+255)>sp[1])begin
            sp[1]=255;
        end
        else begin
            sp[1] = sp[1] - (s2immed[1]);
        end
      end
      else begin
        if ((s2immed[0])>sp[0])begin
            sp[0]=0;
        end
        else begin
            sp[0] = sp[0] - (s2immed[0]);
        end
      end
    end
    else if (s2op[even] == `OPPre) begin
      // Setting pre
      pre[even] <= (s2immed[even]>>12);
      preit[even] <= 1;
    end
  end



  //STAGE FOUR (ODD)
  // ALU and data memory operations
  always @(posedge clk) begin
    s3op[odd] <= (halt[odd] ? `OPnop : s2op[odd]);
    s3inone[odd] <= s2inone[odd];
    s3intwo[odd] <= s2intwo[odd];
    in1 <= s3inone[odd];
    in2 <= s3intwo[odd];
    aluop <= s3op[odd];
    dest[odd] <= s2sp[odd];

    if (s3op[odd] == `OPTest || s3op[odd] == `OPRet) begin
     //Do Nothing
    end
    else if (s3op[odd] == `OPLoad) begin
      regfile[dest[odd]] <= mainmem[result];
    end
    else if (s3op[odd] == `OPStore) begin
      mainmem[regfile[dest[odd]]] <= regfile[result];
      regfile[dest[odd]] <= mainmem[result];
    end
    else begin
      regfile[dest[odd]] <= result;
    end
  end
endmodule

module testbench;
  reg reset = 0;
  reg clk = 0;
  wire halttest;
  integer i = 0;
  processor PE(halttest, reset, clk);
  initial begin
    $dumpfile;
    $dumpvars(0, PE);
    #10 reset = 1;
    #10 reset = 0;
    while (!halttest) begin
      #10 clk = 1;
      #10 clk = 0;
    end
    $finish;
  end
endmodule
