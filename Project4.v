// Processor Module (Matt's)
// Sizes 
`define WORD	[15:0]
`define CacheLine [31:0]
`define Opcode	[15:12]
`define Immed	[11:0]
`define STATE	[7:0]
`define PRE	    [3:0]
`define REGSIZE	[511:0]
`define REGNUM	[7:0]
`define MEMSIZE [131071:0]

// Op-code values

// Instructions with no immediate.
// Uses the last four bits to indicate the instruction type.
`define OPAdd	{ 4'h0, 4'h0 }
`define OPSub	{ 4'h0, 4'h1 }
`define OPTest	{ 4'h0, 4'h2 }
`define OPLt	{ 4'h0, 4'h3 }
`define OPDup	{ 4'h0, 4'h4 }
`define OPAnd	{ 4'h0, 4'h5 }
`define OPOr	{ 4'h0, 4'h6 }
`define OPXor	{ 4'h0, 4'h7 }
`define OPLoad	{ 4'h0, 4'h8 }
`define OPStore	{ 4'h0, 4'h9 }
`define OPRet	{ 4'h0, 4'ha }
`define OPSys	{ 4'h0, 4'hb }

// Instructions with a 16-bit immediate.
// Uses the first four bits to indicate the instruction type.
`define OPPush	{ 4'h1, 4'h0 }
`define OPCall	{ 4'h4, 4'h0 }
`define OPJump	{ 4'h5, 4'h0 }
`define OPJumpF	{ 4'h6, 4'h0 }
`define OPJumpT	{ 4'h7, 4'h0 }

// Instructions with a 12-bit immediate.
// Uses the first four bits to indicate the instruction type.
`define OPGet	{ 4'h8, 4'h0 }
`define OPPut	{ 4'h9, 4'h0 }
`define OPPop	{ 4'ha, 4'h0 }

// The Pre instruction, with a 16-bit immediate.
// Uses the first four bits to indicate the instruction type.
`define OPPre	{ 4'hb, 4'h0 }

//Opcode value for initial state
`define OPInitial {4'hf,4'h0}

module processor(halt, reset, clk);
    output reg [0:1] halt;
    input reset, clk;

    // The stack and memory registers.
    reg `WORD r `REGSIZE;
    reg `WORD m `MEMSIZE;

    // The program counter, instruction register, state number,
    // and stack pointer.
    reg `WORD pc [0:1];
    reg `WORD ir [0:1];
    reg `REGNUM sp [0:1];
    // The destination and source registers.
    reg `REGNUM d_stage3;
    reg `REGNUM s_stage3;
    reg `REGNUM d_stage4;
    reg `REGNUM s_stage4;

    reg `REGNUM fetch_d;
    reg `REGNUM fetch_s;
    reg `WORD fetch_word;

    // The "true-or-false" condition register.
    reg [0:1] torf;

    reg [0:1] pc_check = 0;
    reg `WORD pc_jump [0:1];

    // The Pre register and its load indicator.
    reg [0:1] preit;
    reg `PRE pre [0:1];

    reg thread = 1'b0;
    // Registers for transfering states between stages.
    reg `STATE sn_stage2 = `OPInitial;
    reg `STATE sn_stage3 = `OPInitial;
    reg `STATE sn_stage4 = `OPInitial;
    //Register flag for stalling a thread
    reg [0:1] stalled = 2'b00;
    reg a = 0;
    always @(reset) begin
        halt <= 2'b00;
        pc[0] <= 0;
        pc[1] <= 0;
        sp[0] <= 0;
        sp[1] <= 0;
        sn_stage2 <= `OPInitial;
        sn_stage3 <= `OPInitial;
        sn_stage4 <= `OPInitial;
        ir[0] <= `OPInitial;
        ir[1] <= `OPInitial;
        $readmemh0(r);
        $readmemh1(m);
        thread <= 0;
    end

    always @(posedge clk) begin
        thread <= !thread;
    end

    // TO DO
    // Instantiate slowmem
    // Cache register file
        // define cache size
    // Hash function
    // Prefetch (last)
    // Determine associativity (really though, we're just going to use dirty bit)
    // Determine replacement policy
        // FIFO / FILO (with dirty line preference)
        // Least frequently touched
        // Least recently touched
    
    
    // Stage 1
    always @(posedge clk) begin
        // Get next instruction.
      if(!stalled[thread]) begin

        if (pc_check[thread]) begin
            pc[thread] <= pc_jump[thread]+1; //if we need to jump, set the pc accordingly
            ir[thread] <= m[{thread, pc_jump[thread]}]; // use the provided pc_jump which should point where our next instruction is
            sn_stage2 <= { (m[{thread, pc_jump[thread]}] `Opcode), ((m[{thread, pc_jump[thread]}] `Opcode == 0) ? m[{thread, pc_jump[thread]}][3:0] : 4'b0) };
        end
        else begin
            pc[thread] <= pc[thread] + 1;
            ir[thread] <= m[{thread, pc[thread]}];
            sn_stage2 <= { (m[{thread, pc[thread]}] `Opcode), ((m[{thread, pc[thread]}] `Opcode == 0) ? m[{thread, pc[thread]}][3:0] : 4'b0) };

        end
      end
      else begin
        ir[thread] <= {8'hff, `OPInitial}; //essentially a nop, can change label later --Matthew
        sn_stage2 <= `OPInitial;
      end
    end

    // Stage 2
    always @(posedge clk) begin
        if(pc_check[!thread]) begin
            pc_check[!thread] <= 0;
        end
        if(stalled[!thread]) begin
            stalled[!thread] <= 0;
        end
        case(sn_stage2)
            `OPAdd: begin
                d_stage3 <= sp[!thread] - 1;
                s_stage3 <= sp[!thread];
                sp[!thread] <= sp[!thread] - 1;
                $display("Add thread %b", !thread);
            end
            `OPSub: begin
              s_stage3 <= sp[!thread];
              d_stage3 <= sp[!thread] - 1;
              sp[!thread] <= sp[!thread] - 1;
              $display("Sub thread %b", !thread);
            end
            `OPTest: begin
                s_stage3 <= sp[!thread];
                sp[!thread] <= sp[!thread] - 1;
                stalled[!thread] <= 1;
                $display("Test thread %b, sp = ", !thread, sp[!thread]);
            end
            `OPLt: begin
               d_stage3 <= sp[!thread]-1;
               s_stage3 <= sp[!thread];
               sp[!thread] <= sp[!thread]-1;
               $display("Lt thread %b", !thread);
            end
            `OPDup: begin
               d_stage3 <= sp[!thread] + 1;
               s_stage3 <= sp[!thread];
               sp[!thread] <= sp[!thread] + 1;
               $display("Dup thread %b", !thread);
            end
            `OPAnd: begin
               d_stage3 <= sp[!thread] - 1;
               s_stage3 <= sp[!thread];
               sp[!thread] <= sp[!thread] - 1;
               $display("And thread %b", !thread);
            end
            `OPOr: begin
               d_stage3 <= sp[!thread] - 1;
               s_stage3 <= sp[!thread];
               sp[!thread] <= sp[!thread] - 1;
               $display("Or thread %b", !thread);
            end
            `OPXor: begin
               d_stage3 <= sp[!thread] - 1;
               s_stage3 <= sp[!thread];
               sp[!thread] <= sp[!thread] - 1;
               $display("Xor thread %b", !thread);
            end
            `OPLoad: begin
                d_stage3 <= sp[!thread];
                $display("Load thread %b", !thread);
            end
            `OPStore: begin
               d_stage3 <= sp[!thread] - 1;
               s_stage3 <= sp[!thread];
               sp[!thread] <= sp[!thread] - 1;
               $display("Store thread %b", !thread);
            end
            `OPRet: begin
                s_stage3 <= sp[!thread];
                sp[!thread] <= sp[!thread] - 1;
                pc_check[!thread] <= 1;
                pc_jump[!thread] <= r[{!thread, sp[!thread]}];
                $display("ret thread %b pc = %b, d = %d", !thread, r[{!thread, sp[!thread]}], {!thread, sp[!thread]});
            end
            `OPPush: begin
               d_stage3 <= sp[!thread] + 1;
               sp[!thread] <= sp[!thread] + 1;
               $display("Push thread %b", !thread);
            end
            `OPCall: begin
               d_stage3 <= sp[!thread] + 1;
               sp[!thread] <= sp[!thread] + 1;
               pc_jump[!thread] <= { (preit[!thread] ? pre[!thread] : pc[!thread][15:12]), ir[!thread] `Immed };
               pc_check[!thread] <= 1;
               $display("Call thread %b, d = %b", !thread, sp[!thread] + 1);

             end
             `OPJump: begin
               pc_jump[!thread]  <= { (preit[!thread] ? pre[!thread] : pc[!thread][15:12]), ir[!thread] `Immed };
               pc_check[!thread] <= 1;

               $display("Jump thread %b", !thread);
             end
            `OPJumpF: begin
               if (!torf[!thread]) begin
                  pc_jump[!thread] <= { (preit[!thread] ? pre[!thread] : pc[!thread][15:12]), ir[!thread] `Immed };
                  pc_check[!thread] <= 1;
                  //$display("Jumping on False");
               end
               $display("JumpF thread %b", !thread);

            end
            `OPJumpT: begin
               if (torf[!thread]) begin
                  pc_jump[!thread] <= { (preit[!thread] ? pre[!thread] : pc[!thread][15:12]), ir[!thread] `Immed };
                  pc_check[!thread] <= 1;
               end
               $display("JumpT thread %b", !thread);

            end
            `OPGet: begin
               d_stage3 <= sp[!thread] + 1;
               s_stage3 <= sp[!thread] - (ir[!thread] `REGNUM);
               sp[!thread] <= sp[!thread] + 1;
               $display("Get thread %b", !thread);
            end
            `OPPut: begin
               d_stage3 <= sp[!thread] - (ir[!thread] `REGNUM);
               s_stage3 <= sp[!thread];
               $display("Put thread %b", !thread);
            end
            `OPPre: begin
               pre[!thread] = (ir[!thread] `PRE);
               //preit[!thread] = 1;
               $display("Pre thread %b", !thread);
            end
            `OPPop: begin
              $display("Pop thread %b popping %d vals", !thread, ir[!thread]`REGNUM);
               sp[!thread] <= sp[!thread] - (ir[!thread] `REGNUM);
            end
            // TODO: Add state for each opcode.
            // Set source, destination, and stack pointer for operation.

            `OPInitial: begin
                //I guess this is the equivalent of a NOP? --Matthew
                $display("Initial/NOP thread %b", !thread);
            end
            default: begin
                halt[!thread] <= 1;
                if(thread == 1) begin
                  $display("halt stage 2: %b. thread %b", sn_stage2, !thread);
                end
            end

        endcase
        sn_stage3 <= sn_stage2;
    end

    // Stage 3
    always @(posedge clk) begin

        case (sn_stage3)
            `OPAdd: begin
                fetch_d <= r[{thread, d_stage3}];
                fetch_s <= r[{thread, s_stage3}];
                //$display("Add Stage 3 Thread %b", thread);
            end
            `OPSub: begin
                fetch_d <= r[{thread, d_stage3}];
                fetch_s <= r[{thread, s_stage3}];
            end
            `OPTest: begin
                fetch_s <= r[{thread, s_stage3}];
                //$display("Test stage 3 fetch_s = %b, s_stage3 = %b",  r[{thread, s_stage3}], s_stage3);
            end
            `OPLt: begin
                fetch_d <= r[{thread, d_stage3}];
                fetch_s <= r[{thread, s_stage3}];
            end
            `OPDup: begin
                fetch_s <= r[{thread, s_stage3}];
            end
            `OPAnd: begin
                fetch_d <= r[{thread, d_stage3}];
                fetch_s <= r[{thread, s_stage3}];
                //$display("And Stage 3 Thread %b", thread);
            end
            `OPOr: begin
                fetch_d <= r[{thread, d_stage3}];
                fetch_s <= r[{thread, s_stage3}];
            end
            `OPXor: begin
                fetch_d <= r[{thread, d_stage3}];
                fetch_s <= r[{thread, s_stage3}];
            end
            `OPLoad: begin
                fetch_d <= r[{thread, d_stage3}];
            end
            `OPStore: begin
                fetch_s <= r[{thread, s_stage3}];
                fetch_d <= r[{thread, d_stage3}];
            end
            `OPRet: begin
                //fetch_s <= r[{thread, s_stage3}];
            end
            `OPPush: begin
                fetch_word <= ir[thread];
                //$display("Push Stage 3 Thread %b", thread);
            end
            `OPCall: begin
                fetch_word <= pc[thread];
            end
            `OPPre: begin end
            `OPJump: begin end
            `OPJumpT: begin end
            `OPJumpF: begin end
            `OPGet: begin
                fetch_s <= r[{thread, s_stage3}];
            end
            `OPPut: begin
                fetch_s <= r[{thread, s_stage3}];
            end
            `OPPop: begin end
            `OPInitial: begin
                //I guess this is the equivalent of a NOP? --Matthew
                //$display("Initial Stage 3 Thread %b", thread);
            end
            default: begin
                halt[thread] <= 1;
                //$display("halt stage 3");
            end

        endcase
        sn_stage4 <= sn_stage3;
        d_stage4 <= d_stage3;
        s_stage4 <= s_stage3;
    end

    // Stage 4
    always @(posedge clk) begin
        case(sn_stage4)
            `OPAdd: begin
                r[{!thread, d_stage4}] <= fetch_d + fetch_s;
                //$display("Add Stage 4 !thread %b", !thread);
            end
            `OPSub: begin
                r[{!thread, d_stage4}] <= fetch_d - fetch_s;
            end
            `OPTest: begin
                torf[!thread] <= (fetch_s != 0);
                //$display("test stage 4");
            end
            `OPLt: begin
                r[{!thread, d_stage4}] <= (fetch_d < fetch_s);
            end
            `OPDup: begin
                r[{!thread, d_stage4}] <= fetch_s;
            end
            `OPAnd: begin
                r[{!thread, d_stage4}] <= fetch_d & fetch_s;
                //$display("And Stage 4 !thread %b", !thread);
            end
            `OPOr: begin
                r[{!thread, d_stage4}] <= fetch_d | fetch_s;
            end
            `OPXor: begin
                r[{!thread, d_stage4}] <= fetch_d ^ fetch_s;
            end
            `OPLoad: begin
                r[{!thread, d_stage4}] <= m[fetch_d];
            end
            `OPStore: begin
                m[{!thread, fetch_d}] <= fetch_s;
                r[{!thread, d_stage4}] <= fetch_s;
            end
            `OPRet: begin
                //pc_check[!thread] <= 1;
                //pc_jump[!thread] <= fetch_s;
            end
            `OPPush: begin
                //$display("Push Stage 4 write = %b", { (preit[!thread] ? pre[!thread] : { 4 { fetch_word[11] } } ), fetch_word`Immed });
                r[{!thread, d_stage4}] <= { (preit[!thread] ? pre[!thread] : { 4 { fetch_word[11] } } ), fetch_word`Immed };
                preit <= 0;

            end
            `OPCall: begin
                r[{!thread, d_stage4}] <= fetch_word; //CHANGE back to + 1
                preit <= 0;

            end
            `OPJump: begin preit <= 0; end
            `OPJumpT: begin preit <= 0; end
            `OPJumpF: begin preit <= 0; end
            `OPGet: begin
                r[{!thread, d_stage4}] <= fetch_s;
            end
            `OPPut: begin
                r[{!thread, d_stage4}] <= fetch_s;
            end
            `OPPop: begin end
            `OPPre: begin
                preit[!thread] <= 1;
            end
            `OPInitial: begin
                //$display("Initial Stage 4 !thread %b", !thread);
                //I guess this is the equivalent of a NOP? --Matthew
            end
            default: begin
                halt[!thread] <= 1;
                //$display("halt stage 4");
            end
      endcase
    end
endmodule



// Slow Memory Code
`define MEMDELAY 4

module slowmem(mfc, rdata, addr, wdata, rnotw, strobe, clk);
output reg mfc;
output reg `WORD rdata;
input `WORD addr, wdata;
input rnotw, strobe, clk;
reg [7:0] pend;
reg `WORD raddr;
reg `WORD m `MEMSIZE;

initial begin
  pend <= 0;
  // put your memory initialization code here
end

always @(posedge clk) begin
  if (strobe && rnotw) begin
    // new read request
    raddr <= addr;
    pend <= `MEMDELAY;
  end else begin
    if (strobe && !rnotw) begin
      // do write
      m[addr] <= wdata;
    end

    // pending read?
    if (pend) begin
      // write satisfies pending read
      if ((raddr == addr) && strobe && !rnotw) begin
        rdata <= wdata;
        mfc <= 1;
        pend <= 0;
      end else if (pend == 1) begin
        // finally ready
        rdata <= m[raddr];
        mfc <= 1;
        pend <= 0;
      end else begin
        pend <= pend - 1;
      end
    end else begin
      // return invalid data
      rdata <= 16'hxxxx;
      mfc <= 0;
    end
  end
end
endmodule



// Testbench (Needs editing)
module testbench;

    reg reset = 0;
    reg clk = 0;

    wire [0:1] halted;

    processor PE(halted, reset, clk);

    initial begin
        $dumpfile;
        $dumpvars(0, PE);

        #10 reset = 1;
        #10 reset = 0;

        while (halted != 2'b11) begin
            #10 clk = 1;
            #10 clk = 0;
        end

        $finish;
    end
endmodule
