// Processor Module (Matt's)
`define MEMDELAY 4
// Sizes
`define WORD	[15:0]
`define LINESIZE [31:0]
`define CACHESIZE [15:0]
`define CACHEADDRSIZE [3:0]
`define Addr    [31:22]
`define Data    [21:6]
`define Dirty   [5]
`define Opcode	[15:12]
`define Immed	[11:0]
`define STATE	[7:0]
`define PRE	    [3:0]
`define REGSIZE	[511:0]
`define REGNUM	[7:0]
`define MEMSIZE [131071:0]

`define Hash & 4'b1111//[3:0] //temporary "hash"

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
    //instruction and data caches
    reg `LINESIZE data_cache `CACHESIZE;
    reg `LINESIZE inst_cache `CACHESIZE;

    //main slow memory
    wire mfc;
    wire `WORD rdata;
    reg [16:0] addr;
    reg `WORD wdata;
    reg rnotw;
    reg strobe;
    slowmem Mem1(mfc, rdata, addr, wdata, rnotw, strobe, clk);

    reg data_rnotw;

    reg `WORD data_wdata;
    reg inst_rnotw;

    reg inst_thread; //denotes which thread the current inst read is for
    reg data_thread; //denotes which thread the current data read is for
    reg write_thread; //might not be necessary, we might just have a single register for writing
    //flags dealing with memory
    reg data_trumps_inst[0:1]; //denotes if the data_cache has invoked priority over the inst_cache
    reg data_reading; //we are waiting for slowmem to finish reading for the data_cache
    reg inst_reading; //we are waiting for slowmem to finish reading for the inst_cache
    reg data_writing;
    reg inst_read_stall[0:1];
    reg data_read_stall[0:1];
    reg `WORD data_read_dest[0:1];
    reg `WORD pc_read[0:1];
    reg [16:0] inst_addr[0:1];
    reg [16:0] data_addr[0:1];
    reg [16:0] write_addr[0:1];
    reg `CACHEADDRSIZE data_cache_addr [0:1];
    reg `CACHEADDRSIZE inst_cache_addr [0:1];
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

    //registers for when stage 4 is reading and needs to block the rest of the stages
    reg `REGNUM d4_temp[0:1];
    reg `REGNUM s4_temp[0:1];
    reg `STATE sn4_temp[0:1];
    reg data_was_reading[0:1];

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
        inst_thread <= 0;
        data_thread <= 0;
        inst_reading <= 0;
        data_reading <= 0;
        inst_read_started <= 0;
        data_read_started <= 0;
        inst_read_stall[0] <= 0;
        inst_read_stall[1] <= 0;
        data_read_stall[0] <= 0;
        data_read_stall[1] <= 0;
        $readmemh0(r);
      //  $readmemh1(m);
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
    reg data_read_started = 0;
    reg inst_read_started = 0;
    reg data_write_started = 0;
    reg fetch_complete;
    reg `WORD fetch_data;
    reg reset_reads;
    reg `WORD temp1;
    reg `WORD temp2;

    always @(posedge clk) begin
      temp1 <= inst_addr[0];
      temp2 <= inst_addr[1];
    end
    //memory control block

    always @(posedge clk) begin
        if(reset_reads) begin
          reset_reads <= 0;
          if(data_read_started) data_read_started <= 0;
          else if(inst_read_started) inst_read_started <= 0;
          else if(data_write_started) data_write_started <= 0;
        end
        if(fetch_complete)begin
            fetch_complete <= 0;
            reset_reads <= 1;
            fetch_data <= 16'hxxxx;
        end
        if(data_reading & !data_read_started) begin
            rnotw <= 1;
            addr <= data_addr[data_thread];
            strobe <= 1;
            data_read_started <= 1;
        end
        else if(!data_reading & inst_reading & !inst_read_started) begin
            rnotw <= 1;
            addr <= inst_addr[inst_thread];
            strobe <= 1;
            inst_read_started <= 1;
        end
        else if(data_writing & !data_write_started) begin
            rnotw <= 1'b0;
            wdata <= data_wdata;
            addr <= data_addr[write_thread];
            strobe <= 1;
            $display("memory block writing: wdata = %b, addr = %b", data_wdata, data_addr[write_thread]);
            data_write_started <= 1;
        end
        else if(strobe) strobe <= 0;
        //$display("mfc = ", mfc);
        if(mfc) begin
            fetch_complete <= 1;
            fetch_data <= rdata;
            //$display("mem fetch complete");

        end
        
    end
    // Stage 1
    always @(posedge clk) begin
      if(!stalled[thread] & !(inst_read_stall[thread]) & !(data_read_stall[thread]) & !halt[thread]) begin
        if (pc_check[thread]) begin
            pc[thread] <= pc_jump[thread]+1; //if we need to jump, set the pc accordingly
            //$display(inst_cache[{thread,pc_jump[thread]}`Hash]`Addr == {thread, pc_jump[thread]});
            if(inst_cache[{thread,pc_jump[thread]}`Hash]`Addr == {thread, pc_jump[thread]}) begin
                //$display("hey we got a hit");
                ir[thread] <= inst_cache[{thread,pc_jump[thread]}`Hash];
                sn_stage2 <= { (inst_cache[{thread,pc_jump[thread]}`Hash] `Opcode), ((inst_cache[{thread,pc_jump[thread]}`Hash] `Opcode == 0) ? inst_cache[{thread,pc_jump[thread]}`Hash][3:0] : 4'b0) };
            end
            else begin
                inst_read_stall[thread] <= 1; //signifies that we're not doing anything else until our read is finished
                inst_addr[thread] <= {thread,pc_jump[thread]}; //we need to go ahead and save the address we want
                if(data_reading == 0 & inst_reading == 0) begin //if no one else is reading, setup the read, otherwise we will start waiting with the inst_read_stall flag
                    inst_reading <= 1;
                    inst_thread <= thread;
                    //$display("Instruction reading");
                end
                ir[thread] <= {8'hff, `OPInitial};
                sn_stage2 <= `OPInitial;
            end
        end //if(pc_check)
        else begin
            //$display("incrementing pc: ");
            pc[thread] <= pc[thread] + 1;
            if(inst_cache[{thread,pc[thread]}`Hash]`Addr == {thread, pc[thread]}) begin
                ir[thread] <= inst_cache[{thread,pc[thread]}`Hash];
                sn_stage2 <= { (inst_cache[{thread,pc[thread]}`Hash] `Opcode), ((inst_cache[{thread,pc[thread]}`Hash] `Opcode == 0) ? inst_cache[{thread,pc[thread]}`Hash][3:0] : 4'b0) };
                $display("hey we got a hit");
            end
            else begin
                //$display("writing to addr. thread = %b, addr = %b", thread, {thread, pc[thread]});
                inst_addr[thread] <= {thread,pc[thread]};
                inst_read_stall[thread] <= 1;
                //$display("first read: addr = %b, thread = %b, inst_reading = %b", {thread, pc[thread]}, thread, inst_reading);
                if(data_reading == 0 & inst_reading == 0) begin //only hitting this one at the begining
                    inst_reading <= 1;
                    inst_thread <= thread;
                end
                ir[thread] <= {8'hff, `OPInitial};
                sn_stage2 <= `OPInitial;
            end
        end
      end
      else if (!stalled[thread] & inst_read_stall[thread] & (inst_thread != thread) & !halt[thread]) begin //this means we are waiting behind a inst_read, but it's on the other thread
        if(!inst_reading & !data_reading) begin //this means neither is reading, so it must be our turn
          //$display("our turn");
          inst_reading <= 1;
          inst_thread <= thread;
        end
        ir[thread] <= {8'hff, `OPInitial};
        sn_stage2 <= `OPInitial;
      end
      else if(!stalled[thread] & inst_read_stall[thread] & (inst_thread == thread) & !halt[thread]) begin //this means this thread wants to read and it is its turn to read
          if(inst_reading & !data_reading) begin //this means we are currently reading from slowmem
              if(fetch_complete) begin //READ COMPLETE
                  ir[thread] <= fetch_data;
                  sn_stage2 <= { (fetch_data `Opcode), ((fetch_data`Opcode == 0) ? fetch_data[3:0] : 4'b0) };
                  inst_cache[inst_addr[thread]`Hash] <= {inst_addr[thread][9:0], fetch_data, 6'b000000 }; //TODO: addr probably needs to be something else, that might not still have the address we want
                  inst_read_stall[thread] <= 0;
                  inst_reading <= 0;
                  if(inst_read_stall[!thread]) begin
                    //$display("swapping thread to waiting: thread = %b, addr = %b", !thread, {!thread, pc[!thread]});
                    inst_thread <= !thread;
                    //inst_addr[!thread] <= {!thread, pc[!thread]};
                    //$display("swapping the thread");
                  end
                  //$display("instruction read complete");
              end
              else begin //we are still reading, send NOPS
                  ir[thread] <= {8'hff, `OPInitial};
                  sn_stage2 <= `OPInitial;
              end
          end
          else begin //this means we are waiting behind a data read
              if(data_reading == 0) begin //this means the data read we were waiting on is over, now we do our read
                  inst_reading <= 1;
                  inst_thread <= thread;
              end
              ir[thread] <= {8'hff, `OPInitial}; //either we are still waiting or we just started. Either way, send a NOP
              sn_stage2 <= `OPInitial;
          end
      end//replace it here
      else if(!stalled[thread] & data_reading & (data_thread == thread) & !halt[thread]) begin //this means there is a data read going on, we need to send NOPS down the pipe (i think)
        ir[thread] <= {8'hff, `OPInitial};
        sn_stage2 <= `OPInitial;
      end
      else begin
        ir[thread] <= {8'hff, `OPInitial};
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
                stalled[!thread] <= 1; //makes things easier if the instruction following a load is a NOP
              //  read_stall[!thread] <= 1; //we might have to have multiple nops, this signifies that
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
                //$display("Initial/NOP thread %b", !thread);
            end
            default: begin
                halt[!thread] <= 1;
                //if(thread == 1) begin
                  $display("halt stage 2: %b. thread %b", sn_stage2, !thread);
                //end
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
        //check if data is currently being read
        
        if(!data_reading) begin
          if(data_was_reading[thread]) begin //if not check if it was being read (so we need to send the state we've saved)
              sn_stage4 <= sn4_temp[thread];
              d_stage4 <= d4_temp[thread];
              s_stage4 <= s4_temp[thread];
              data_was_reading[thread] <= 0;
          end
          else begin
              sn_stage4 <= sn_stage3;
              d_stage4 <= d_stage3;
              s_stage4 <= s_stage3;
          end
        end
        else if(data_thread == thread) begin
          sn4_temp[thread] <= sn_stage3;
          d4_temp[thread] <= d_stage3;
          s4_temp[thread] <= s_stage3;
          data_was_reading[thread] <= 1;
        end
        
    end

    // Stage 4
    always @(posedge clk) begin
     if(data_writing) data_writing <= 0;

     if(!data_read_stall[!thread]) begin //this thread wants to be reading
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
                  //will have to set flag to denote memory is being read
                  data_read_stall[!thread] <= 1;
                  //data_cache_addr[!thread] <= fetch_d;
                  data_addr[!thread] <= fetch_d;
                  data_read_dest[!thread] <= {!thread, d_stage4};
                  if(!data_reading) begin //there isn't a data read already going on, so we should go ahead and start reading
                      data_reading <= 1;
                      data_thread <= !thread;
                  end
                  $display("Load: dest = %b", {!thread, d_stage4});
                  //r[{!thread, d_stage4}] <= m[fetch_d];
              end
              `OPStore: begin
                  //m[{!thread, fetch_d}] <= fetch_s;
                  $display("Store: wdata = %b, addr = %b", fetch_s, {!thread, d_stage4});
                  data_writing <= 1;
                  data_wdata <= fetch_s;
                  write_thread <= !thread;
                  data_addr[!thread] <= {!thread, d_stage4};
                  r[{!thread, d_stage4}] <= fetch_s;
              end
              `OPRet: begin
              end
              `OPPush: begin
                  r[{!thread, d_stage4}] <= { (preit[!thread] ? pre[!thread] : { 4 { fetch_word[11] } } ), fetch_word`Immed };
                  preit <= 0;
                  $display("Push stage 4");

              end
              `OPCall: begin
                  r[{!thread, d_stage4}] <= fetch_word;
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
              end
              default: begin
                  halt[!thread] <= 1;
              end
        endcase
      end
     else if(data_read_stall[!thread] & data_thread == !thread) begin //there is currently a data read out
        if(fetch_complete) begin //READ COMPLETE
            $display("read complete: dest = %b, data = %b", data_read_dest[!thread], fetch_data);
            r[data_read_dest[!thread]] <= fetch_data;
            //have to deal with the possibility of the line being dirty
            //(just do the write shouldn't be able to have a write overlap)
            if(data_cache[data_addr[!thread]`Hash]`Dirty) begin
                data_writing <= 1;
                data_wdata <= data_cache[data_addr[!thread]`Hash]`Data;
            end
            data_cache[data_addr[!thread]`Hash] <= {data_addr[!thread][9:0], fetch_data, 6'b000000};
            data_read_stall[!thread] <= 0;
            data_reading <= 0;
            if(data_read_stall[thread])
                data_thread <= thread;
        end
     end
     else if(data_read_stall[!thread] & data_thread != !thread) begin //means that the current read is on the other thread
        if(!data_reading) begin //the read that was going has finished, so we should be good to start
            data_reading <= 1;
            data_thread <= !thread;
        end
     end
  end
endmodule



// Slow Memory Code


module slowmem(mfc, rdata, addr, wdata, rnotw, strobe, clk);
output reg mfc;
output reg `WORD rdata;
input [16:0] addr;
input `WORD wdata;
input rnotw, strobe, clk;
reg [7:0] pend;
reg [16:0] raddr;
reg `WORD m `MEMSIZE;
reg `WORD write_temp;
initial begin
  pend <= 0;

  // put your memory initialization code here
  $readmemh1(m);
end

always @(posedge clk) begin
  if (strobe && rnotw) begin
    // new read request
    $display("new read request");
    raddr <= addr;
    pend <= `MEMDELAY;
  //  $display("saw the strobe");
  end else begin
    if (strobe && !rnotw) begin
      // do write
      m[addr] <= wdata;
      $display("doing the write: data = %b, addr = %b", wdata, addr);
      write_temp <= wdata;
    end

    // pending read?
    if (pend) begin
      //$display("pend is > 1 at least once");
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
        //$display("location: %b data: %b",raddr, m[raddr]);
        //$display("finally read");
      end else begin
        pend <= pend - 1;
        //$display("decrement pend");
      end
    end else begin
      // return invalid data
      //$display("invalid data");
      rdata <= 16'hxxxx;
      mfc <= 0;
    end
  end
end
endmodule


module testbench;

    reg reset = 0;
    reg clk = 0;

    wire [0:1] halted;
    integer a = 0;
    processor PE(halted, reset, clk);

    initial begin
        $dumpfile;
        $dumpvars(0, PE);

        #10 reset = 1;
        #10 reset = 0;

        while (!halted[0]|!halted[1]) begin
            #10 clk = 1;
            #10 clk = 0;
            a = a + 1;
        end

        $finish;
    end
endmodule
