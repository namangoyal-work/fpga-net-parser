module eth_parser #(
  parameter logic [47:0] MY_MAC = 48'h02_00_00_00_00_01
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
  output logic       mac_ok,
  output logic       type_ok,
  output logic       hdr_done
);

  assign m_tdata  = s_tdata;
  assign m_tvalid = s_tvalid;
  assign m_tlast  = s_tlast;
  assign s_tready = m_tready;

  wire beat = s_tvalid && s_tready;

  logic [3:0]  count;
  logic        mac_match;
  logic        bcast_match;
  logic [15:0] ethertype;

  logic [7:0] mac_byte;
  always_comb begin
    case (count)
      4'd0:    mac_byte = MY_MAC[47:40];
      4'd1:    mac_byte = MY_MAC[39:32];
      4'd2:    mac_byte = MY_MAC[31:24];
      4'd3:    mac_byte = MY_MAC[23:16];
      4'd4:    mac_byte = MY_MAC[15:8];
      default: mac_byte = MY_MAC[7:0];
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      count       <= '0;
      mac_match   <= 1'b0;
      bcast_match <= 1'b0;
      hdr_done    <= 1'b0;
      ethertype   <= '0;
    end else if (beat) begin
      if (s_tlast) count <= '0;
      else if (count < 4'd14) count <= count + 4'd1;

      if (count == 4'd0) begin
        mac_match   <= (s_tdata == MY_MAC[47:40]);
        bcast_match <= (s_tdata == 8'hFF);
        hdr_done    <= 1'b0;
      end else if (count < 4'd6) begin
        if (s_tdata != mac_byte) mac_match   <= 1'b0;
        if (s_tdata != 8'hFF)    bcast_match <= 1'b0;
      end

      if (count == 4'd12) ethertype[15:8]  <= s_tdata;
      if (count == 4'd13) begin
        ethertype[7:0] <= s_tdata;
        hdr_done <= 1'b1;
      end
    end
  end

  assign mac_ok  = hdr_done && (mac_match || bcast_match);
  assign type_ok = hdr_done && (ethertype == 16'h0800);

endmodule
