module l1_trigger #(
  parameter LATENCY = 4
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
  input  logic       mac_ok,
  input  logic       type_ok,
  input  logic       ip_ok,
  input  logic       udp_ok,
  output logic       verdict_valid,
  output logic       verdict
);

  assign m_tdata  = s_tdata;
  assign m_tvalid = s_tvalid;
  assign m_tlast  = s_tlast;
  assign s_tready = m_tready;

  wire beat = s_tvalid && s_tready;

  logic [5:0] count;
  logic       ev_q, runt_q;

  wire hdr_event  = beat && (count == 6'd39);
  wire runt_event = beat && s_tlast && (count < 6'd39);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      count  <= '0;
      ev_q   <= 1'b0;
      runt_q <= 1'b0;
    end else begin
      if (beat) begin
        if (s_tlast)            count <= '0;
        else if (count < 6'd40) count <= count + 6'd1;
      end
      ev_q   <= hdr_event;
      runt_q <= runt_event;
    end
  end

  wire decision = runt_q ? 1'b0 : (mac_ok && type_ok && ip_ok && udp_ok);

  localparam P = LATENCY - 1;
  logic [P-1:0] v_pipe;
  logic [P-1:0] d_pipe;

  integer i;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      v_pipe <= '0;
      d_pipe <= '0;
    end else begin
      v_pipe[0] <= ev_q || runt_q;
      d_pipe[0] <= decision;
      for (i = 1; i < P; i = i + 1) begin
        v_pipe[i] <= v_pipe[i-1];
        d_pipe[i] <= d_pipe[i-1];
      end
    end
  end

  assign verdict_valid = v_pipe[P-1];
  assign verdict       = d_pipe[P-1];

`ifdef FORMAL
  // Prove the defining property of an L1 trigger: the verdict pulse lands a
  // constant LATENCY cycles after its anchor event, for every input, always.
  // This is the "fixed latency" guarantee made machine-checked.
  reg [7:0] f_init = 8'd0;
  always @(posedge clk) if (f_init != 8'hFF) f_init <= f_init + 8'd1;

  // Start in reset, then hold it deasserted: examine steady-state operation.
  initial assume (!rst_n);
  always @(posedge clk) if (f_init != 8'd0) assume (rst_n);

  always @(posedge clk) begin
    if (f_init > LATENCY && rst_n) begin
      // verdict_valid now  <=>  an anchor event exactly LATENCY cycles ago.
      assert (verdict_valid == $past(hdr_event || runt_event, LATENCY));

      // Security invariant (no bad accept): an ACCEPT verdict can only be
      // emitted if, at the anchor cycle, every validation flag was asserted and
      // the frame was not a runt. The pipeline can never manufacture an accept.
      if (verdict_valid && verdict) begin
        assert (!$past(runt_q,  P));
        assert ( $past(mac_ok,  P));
        assert ( $past(type_ok, P));
        assert ( $past(ip_ok,   P));
        assert ( $past(udp_ok,  P));
      end
    end
  end
`endif

endmodule
