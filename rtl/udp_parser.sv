module udp_parser #(
  parameter logic [15:0] LISTEN_PORT = 16'd14310
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [7:0]  s_tdata,
  input  logic        s_tvalid,
  input  logic        s_tlast,
  output logic        s_tready,
  output logic [7:0]  m_tdata,
  output logic        m_tvalid,
  output logic        m_tlast,
  input  logic        m_tready,
  output logic        udp_done,
  output logic        udp_ok,
  output logic [15:0] src_port,
  output logic [15:0] dst_port,
  output logic [15:0] udp_len
);

  assign m_tdata  = s_tdata;
  assign m_tvalid = s_tvalid;
  assign m_tlast  = s_tlast;
  assign s_tready = m_tready;

  wire beat = s_tvalid && s_tready;

  logic [5:0] count;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      count    <= '0;
      udp_done <= 1'b0;
    end else if (beat) begin
      if (s_tlast) count <= '0;
      else if (count < 6'd40) count <= count + 6'd1;

      if (count == 6'd0) udp_done <= 1'b0;

      if (count == 6'd34) src_port[15:8] <= s_tdata;
      if (count == 6'd35) src_port[7:0]  <= s_tdata;
      if (count == 6'd36) dst_port[15:8] <= s_tdata;
      if (count == 6'd37) dst_port[7:0]  <= s_tdata;
      if (count == 6'd38) udp_len[15:8]  <= s_tdata;
      if (count == 6'd39) begin
        udp_len[7:0] <= s_tdata;
        udp_done     <= 1'b1;
      end
    end
  end

  assign udp_ok = udp_done && (dst_port == LISTEN_PORT) && (udp_len >= 16'd8);

endmodule
