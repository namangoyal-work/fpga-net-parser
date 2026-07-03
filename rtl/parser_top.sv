module parser_top #(
  parameter logic [47:0] MY_MAC      = 48'h02_00_00_00_00_01,
  parameter logic [15:0] LISTEN_PORT = 16'd14310,
  parameter              LATENCY     = 4
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic [7:0] s_tdata,
  input  logic       s_tvalid,
  input  logic       s_tlast,
  output logic       s_tready,
  output logic [7:0] m_tdata,
  output logic       m_tvalid,
  output logic       m_tlast,
  input  logic       m_tready,
  output logic       verdict_valid,
  output logic       verdict
);
  logic [7:0] d1, d2, d3;
  logic       v1, v2, v3;
  logic       l1_, l2, l3;
  logic       r1, r2, r3;
  logic       mac_ok, type_ok, ip_ok, udp_ok;

  eth_parser #(.MY_MAC(MY_MAC)) u_eth (
    .clk(clk), .rst_n(rst_n),
    .s_tdata(s_tdata), .s_tvalid(s_tvalid), .s_tlast(s_tlast), .s_tready(s_tready),
    .m_tdata(d1), .m_tvalid(v1), .m_tlast(l1_), .m_tready(r1),
    .mac_ok(mac_ok), .type_ok(type_ok), .hdr_done()
  );
  ipv4_parser u_ipv4 (
    .clk(clk), .rst_n(rst_n),
    .s_tdata(d1), .s_tvalid(v1), .s_tlast(l1_), .s_tready(r1),
    .m_tdata(d2), .m_tvalid(v2), .m_tlast(l2), .m_tready(r2),
    .ip_done(), .ip_ok(ip_ok), .src_ip(), .dst_ip(), .total_len()
  );
  udp_parser #(.LISTEN_PORT(LISTEN_PORT)) u_udp (
    .clk(clk), .rst_n(rst_n),
    .s_tdata(d2), .s_tvalid(v2), .s_tlast(l2), .s_tready(r2),
    .m_tdata(d3), .m_tvalid(v3), .m_tlast(l3), .m_tready(r3),
    .udp_done(), .udp_ok(udp_ok), .src_port(), .dst_port(), .udp_len()
  );
  l1_trigger #(.LATENCY(LATENCY)) u_trig (
    .clk(clk), .rst_n(rst_n),
    .s_tdata(d3), .s_tvalid(v3), .s_tlast(l3), .s_tready(r3),
    .m_tdata(m_tdata), .m_tvalid(m_tvalid), .m_tlast(m_tlast), .m_tready(m_tready),
    .mac_ok(mac_ok), .type_ok(type_ok), .ip_ok(ip_ok), .udp_ok(udp_ok),
    .verdict_valid(verdict_valid), .verdict(verdict)
  );
endmodule
