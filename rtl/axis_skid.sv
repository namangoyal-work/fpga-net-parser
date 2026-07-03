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
      m_tvalid <= 1'b0;
      state    <= EMPTY;
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

endmodule