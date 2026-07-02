module axis_passthrough(
    input logic clk,
    input logic rst_n,
    input logic[7:0] s_tdata,
    input logic s_tvalid,
    input logic s_tlast,
    output logic s_tready,
    output logic [7:0] m_tdata,
    output logic m_tvalid,
    output logic m_tlast,
    input logic m_tready
);

assign m_tdata  = s_tdata;
assign m_tvalid = s_tvalid;
assign m_tlast  = s_tlast;
assign s_tready = m_tready;





endmodule