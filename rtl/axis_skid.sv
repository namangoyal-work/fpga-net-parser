module axis_skid (
  input  logic       clk,
  input  logic       rst_n,
  input  logic [7:0] s_tdata,
  input  logic       s_tvalid,
  input  logic       s_tlast,
  output logic       s_tready,
  output logic [7:0] m_tdata,
  output logic       m_tvalid,
  output logic       m_tlast,
  input  logic       m_tready
);

  typedef enum logic [0:0] {EMPTY, FULL} state_t;
  state_t state;

  logic [7:0] skid_data;   
  logic       skid_last;

  wire s_beat    = s_tvalid && s_tready;
  wire m_beat    = m_tvalid && m_tready;
  wire out_ready = !m_tvalid || m_beat;

  assign s_tready = (state == EMPTY);   

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      m_tvalid  <= 1'b0;
      m_tdata   <= '0;
      m_tlast   <= 1'b0;
      skid_data <= '0;
      skid_last <= 1'b0;
      state     <= EMPTY;
    end else begin
      if (out_ready) begin
        if (state == FULL) begin
            m_tdata <= skid_data;
            m_tlast <= skid_last;
            m_tvalid <= 1'b1;
            state <= EMPTY;

        end else begin
          m_tdata <= s_tdata;
          m_tlast <= s_tlast;
          m_tvalid <= s_beat;
          
        end
      end else begin
        if (s_beat) begin

          skid_data <= s_tdata;
          skid_last <= s_tlast;
          state <= FULL;
        end
      end
    end
  end

`ifdef FORMAL
  // Formal proof of the AXI-Stream contract. Enabled only under SymbiYosys.
  reg f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;

  always @(posedge clk) begin
    if (f_past_valid && $past(rst_n) && rst_n) begin
      // Assume the upstream producer is AXI-Stream compliant: a valid offer is
      // held stable until it is accepted.
      if ($past(s_tvalid && !s_tready)) begin
        assume (s_tvalid);
        assume (s_tdata == $past(s_tdata));
        assume (s_tlast == $past(s_tlast));
      end

      // Prove our downstream interface honours the same contract: once a valid
      // beat is offered we never retract it or mutate the payload before accept.
      if ($past(m_tvalid && !m_tready)) begin
        assert (m_tvalid);
        assert (m_tdata == $past(m_tdata));
        assert (m_tlast == $past(m_tlast));
      end

      // Liveness: FULL plus a ready consumer drains to EMPTY on the next cycle.
      if ($past(state == FULL) && $past(m_tready))
        assert (state == EMPTY);
    end

    // Single-slot backpressure invariant: never accept input while occupied.
    // This is precisely why one skid slot suffices for one-cycle-late ready.
    if (rst_n && state == FULL)
      assert (!s_tready);
  end
`endif

endmodule