module ipv4_parser (
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
  output logic        ip_done,
  output logic        ip_ok,
  output logic [31:0] src_ip,
  output logic [31:0] dst_ip,
  output logic [15:0] total_len
);

  assign m_tdata  = s_tdata;
  assign m_tvalid = s_tvalid;
  assign m_tlast  = s_tlast;
  assign s_tready = m_tready;

  wire beat = s_tvalid && s_tready;

  logic [5:0]  count;
  logic        ver_ihl_ok;
  logic        nofrag_ok;
  logic        proto_ok;
  logic [31:0] csum;

  // Checksum fold, pipelined across three cycles so each stage is a short path
  // and the carry chain never feeds combinationally into the L1 trigger.
  logic [16:0] fold1_r;    // stage 1: csum[15:0] + csum[31:16], registered at byte 34
  logic [15:0] fold2_r;    // stage 2: add the end-around carry back in, registered at byte 35
  logic        csum_ok_r;  // stage 3: final ones'-complement compare, registered at byte 36

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      count      <= '0;
      ip_done    <= 1'b0;
      ver_ihl_ok <= 1'b0;
      nofrag_ok  <= 1'b0;
      proto_ok   <= 1'b0;
      csum       <= '0;
      src_ip     <= '0;
      dst_ip     <= '0;
      total_len  <= '0;
      fold1_r    <= '0;
      fold2_r    <= '0;
      csum_ok_r  <= 1'b0;
    end else if (beat) begin
      if (s_tlast) count <= '0;
      else if (count < 6'd40) count <= count + 1'b1;

      if (count == 6'd0) begin
        ip_done    <= 1'b0;
        ver_ihl_ok <= 1'b0;
        nofrag_ok  <= 1'b1;
        proto_ok   <= 1'b0;
        csum       <= '0;
      end

      if (count == 6'd14) ver_ihl_ok <= (s_tdata == 8'h45);
      if (count == 6'd16) total_len[15:8] <= s_tdata;
      if (count == 6'd17) total_len[7:0]  <= s_tdata;
      if (count == 6'd20 && (s_tdata & 8'h3F) != 8'h00) nofrag_ok <= 1'b0;
      if (count == 6'd21 && s_tdata != 8'h00)           nofrag_ok <= 1'b0;
      if (count == 6'd23) proto_ok <= (s_tdata == 8'd17);

      if (count >= 6'd26 && count <= 6'd29) src_ip <= {src_ip[23:0], s_tdata};
      if (count >= 6'd30 && count <= 6'd33) dst_ip <= {dst_ip[23:0], s_tdata};

      if (count >= 6'd14 && count <= 6'd33) begin
        if (!count[0]) csum <= csum + {16'h0, s_tdata, 8'h00};
        else           csum <= csum + {24'h0, s_tdata};
      end

      if (count == 6'd33) ip_done <= 1'b1;

      // csum holds the full sum from byte 34 onward; fold it in three registered
      // steps (fold, add end-around carry, compare) so each stage is a short path.
      if (count == 6'd34) fold1_r   <= csum[15:0] + csum[31:16];
      if (count == 6'd35) fold2_r   <= fold1_r[15:0] + {15'b0, fold1_r[16]};
      if (count == 6'd36) csum_ok_r <= (fold2_r == 16'hFFFF);
    end
  end

  assign ip_ok = ip_done && ver_ihl_ok && nofrag_ok && proto_ok && csum_ok_r;

endmodule
