// QSA top level: AXI4-Lite register block + control core (spec v1.0)
//   AXI4-Lite slave : configuration, control, status
//   AXI4-Stream slave : K input beats, {B row, A column} per beat
//   AXI4-Stream master: N output rows
//   irq = STATUS.done AND IRQ_EN
module qsa_top #(
    parameter N = 4
) (
    input  wire                  aclk,
    input  wire                  aresetn,

    // AXI4-Lite slave
    input  wire [7:0]            s_axil_awaddr,
    input  wire                  s_axil_awvalid,
    output wire                  s_axil_awready,
    input  wire [31:0]           s_axil_wdata,
    input  wire [3:0]            s_axil_wstrb,
    input  wire                  s_axil_wvalid,
    output wire                  s_axil_wready,
    output wire [1:0]            s_axil_bresp,
    output wire                  s_axil_bvalid,
    input  wire                  s_axil_bready,
    input  wire [7:0]            s_axil_araddr,
    input  wire                  s_axil_arvalid,
    output wire                  s_axil_arready,
    output wire [31:0]           s_axil_rdata,
    output wire [1:0]            s_axil_rresp,
    output wire                  s_axil_rvalid,
    input  wire                  s_axil_rready,

    // AXI4-Stream slave (input)
    input  wire [16*N-1:0]       s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    // AXI4-Stream master (output)
    output wire [8*N-1:0]        m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast,

    output wire                  irq
);

wire [8:0]         k_w;
wire [15:0]        m_w;
wire [4:0]         s_w;
wire signed [7:0]  zp_w;
wire               relu_w;
wire [32*N-1:0]    bias_w;
wire               start_w, soft_rst_w, done_clr_w, err_clr_w;
wire               busy_w, done_w, err_w;

qsa_regs #(.N(N)) u_regs (
    .aclk_i(aclk), .aresetn_i(aresetn),
    .s_awaddr_i(s_axil_awaddr), .s_awvalid_i(s_axil_awvalid), .s_awready_o(s_axil_awready),
    .s_wdata_i(s_axil_wdata), .s_wstrb_i(s_axil_wstrb), .s_wvalid_i(s_axil_wvalid), .s_wready_o(s_axil_wready),
    .s_bresp_o(s_axil_bresp), .s_bvalid_o(s_axil_bvalid), .s_bready_i(s_axil_bready),
    .s_araddr_i(s_axil_araddr), .s_arvalid_i(s_axil_arvalid), .s_arready_o(s_axil_arready),
    .s_rdata_o(s_axil_rdata), .s_rresp_o(s_axil_rresp), .s_rvalid_o(s_axil_rvalid), .s_rready_i(s_axil_rready),
    .busy_i(busy_w), .done_i(done_w), .err_i(err_w),
    .k_o(k_w), .m_o(m_w), .s_o(s_w), .zp_o(zp_w), .relu_o(relu_w), .bias_o(bias_w),
    .start_o(start_w), .soft_rst_o(soft_rst_w), .done_clr_o(done_clr_w), .err_clr_o(err_clr_w),
    .irq_o(irq)
);

qsa_core #(.N(N)) u_core (
    .clk_i(aclk), .rst_i(~aresetn), .soft_rst_i(soft_rst_w), .start_i(start_w),
    .done_clr_i(done_clr_w), .err_clr_i(err_clr_w),
    .k_i(k_w), .m_i(m_w), .s_i(s_w), .zp_i(zp_w), .relu_i(relu_w), .bias_i(bias_w),
    .s_tvalid_i(s_axis_tvalid), .s_tready_o(s_axis_tready), .s_tdata_i(s_axis_tdata), .s_tlast_i(s_axis_tlast),
    .m_tvalid_o(m_axis_tvalid), .m_tready_i(m_axis_tready), .m_tdata_o(m_axis_tdata), .m_tlast_o(m_axis_tlast),
    .busy_o(busy_w), .done_o(done_w), .err_len_o(err_w)
);

endmodule : qsa_top
