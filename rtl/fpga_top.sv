// Board bring-up wrapper for the Arty A7-100T.
// Streams a stored Ethernet/IPv4/UDP frame through parser_top in a loop and
// shows the trigger verdict on an LED.
//   sw[0] = 0 : frame is sent intact           -> parser accepts -> led[0] ON
//   sw[0] = 1 : UDP dest port is corrupted live -> parser rejects -> led[0] OFF
//   btn[0]    : reset
//   led[3]    : ~1.5 Hz heartbeat (proves the bitstream is running)
module fpga_top (
  input  logic       CLK100MHZ,
  input  logic [3:0] sw,
  input  logic [3:0] btn,
  output logic [3:0] led
);
  wire clk   = CLK100MHZ;
  wire rst_n = ~btn[0];               // btn0 pressed -> reset

  localparam int N   = 53;            // frame length in bytes
  localparam int GAP = 16;            // idle cycles between frames

  logic [7:0] rom [0:N-1];
  initial begin
    rom[0] = 8'h02;  rom[1] = 8'h00;  rom[2] = 8'h00;  rom[3] = 8'h00;
    rom[4] = 8'h00;  rom[5] = 8'h01;  rom[6] = 8'h02;  rom[7] = 8'h00;
    rom[8] = 8'h00;  rom[9] = 8'h00;  rom[10] = 8'h00; rom[11] = 8'h02;
    rom[12] = 8'h08; rom[13] = 8'h00; rom[14] = 8'h45; rom[15] = 8'h00;
    rom[16] = 8'h00; rom[17] = 8'h27; rom[18] = 8'h00; rom[19] = 8'h01;
    rom[20] = 8'h00; rom[21] = 8'h00; rom[22] = 8'h40; rom[23] = 8'h11;
    rom[24] = 8'h66; rom[25] = 8'hc3; rom[26] = 8'h0a; rom[27] = 8'h00;
    rom[28] = 8'h00; rom[29] = 8'h01; rom[30] = 8'h0a; rom[31] = 8'h00;
    rom[32] = 8'h00; rom[33] = 8'h02; rom[34] = 8'h13; rom[35] = 8'h88;
    rom[36] = 8'h37; rom[37] = 8'he6; rom[38] = 8'h00; rom[39] = 8'h13;
    rom[40] = 8'h0e; rom[41] = 8'h89; rom[42] = 8'h68; rom[43] = 8'h65;
    rom[44] = 8'h6c; rom[45] = 8'h6c; rom[46] = 8'h6f; rom[47] = 8'h20;
    rom[48] = 8'h77; rom[49] = 8'h6f; rom[50] = 8'h72; rom[51] = 8'h6c;
    rom[52] = 8'h64;
  end

  logic [7:0] idx;
  always_ff @(posedge clk) begin
    if (!rst_n)                  idx <= 8'd0;
    else if (idx == N + GAP - 1) idx <= 8'd0;
    else                         idx <= idx + 8'd1;
  end

  wire streaming = (idx < N);

  logic [7:0] cur;
  always_comb begin
    cur = rom[idx[5:0]];
    if (sw[0] && idx == 8'd36) cur = rom[36] ^ 8'hFF;   // corrupt UDP dport
  end

  logic [7:0] s_tdata;
  logic       s_tvalid, s_tlast, s_tready;
  logic       verdict_valid, verdict;

  assign s_tdata  = cur;
  assign s_tvalid = streaming;
  assign s_tlast  = (idx == N - 1);

  parser_top u_parser (
    .clk(clk), .rst_n(rst_n),
    .s_tdata(s_tdata), .s_tvalid(s_tvalid), .s_tlast(s_tlast), .s_tready(s_tready),
    .m_tdata(), .m_tvalid(), .m_tlast(), .m_tready(1'b1),
    .verdict_valid(verdict_valid), .verdict(verdict)
  );

  logic verdict_led;
  always_ff @(posedge clk) begin
    if (!rst_n)             verdict_led <= 1'b0;
    else if (verdict_valid) verdict_led <= verdict;
  end

  logic [25:0] beat;
  always_ff @(posedge clk) begin
    if (!rst_n) beat <= '0;
    else        beat <= beat + 26'd1;
  end

  assign led[0] = verdict_led;      // accept indicator
  assign led[1] = verdict_valid;    // flashes each verdict
  assign led[2] = 1'b0;
  assign led[3] = beat[25];         // heartbeat
endmodule
