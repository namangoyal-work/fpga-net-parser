`timescale 1ns/1ps
module axis_passthrough_tb;
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;              // 100 MHz clock, forever

  logic [7:0] s_tdata,  m_tdata;
  logic       s_tvalid, s_tlast, s_tready;
  logic       m_tvalid, m_tlast, m_tready;

  axis_passthrough dut (.*);         // .* auto-connects same-named ports

  int errors = 0;

  task automatic send_and_check(input logic [7:0] b, input logic last);
    // drive s_tdata, s_tvalid=1, s_tlast=last
    // @(posedge clk); #1;   <- wait one edge, then a moment for signals to settle
    // check m_tdata==b, m_tvalid==1, m_tlast==last
    // on mismatch: $error("..."); errors++;
  endtask

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, axis_passthrough_tb);
    // 1. hold rst_n low for 2 clock edges, then release it
    // 2. m_tready = 1;
    // 3. send DE, AD, BE, EF — last=1 only on EF
    // 4. drop s_tvalid; check m_tvalid follows it low
    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
