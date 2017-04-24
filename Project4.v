






// Slow Memory Code

`define WORD [15:0]
`define MEMSIZE [65535:0]
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
