// QSA AXI4-Lite register block (spec v1.0, Sections 6 and 8)
// One outstanding write and one outstanding read at a time. WSTRB is ignored.
// Mapped addresses respond OKAY, unmapped addresses respond SLVERR (reads return 0).
//
// Address map (byte address, bits [1:0] ignored):
//   0x00 CTRL    bit0 start (self-clearing), bit1 soft_reset (self-clearing), bit2 relu_en
//   0x04 STATUS  bit0 busy (RO), bit1 done (W1C), bit2 err_len (W1C)
//   0x08 K       [8:0]      0x0C QM [15:0]     0x10 QS [4:0]     0x14 ZP [7:0]
//   0x18 IRQ_EN  bit0
//   0x20 + 4i    BIAS[i], i = 0 to N-1
module qsa_regs #(
    parameter N = 4
) (
    input  wire                  aclk_i,
    input  wire                  aresetn_i,

    // AXI4-Lite slave
    input  wire [7:0]            s_awaddr_i,
    input  wire                  s_awvalid_i,
    output wire                  s_awready_o,
    input  wire [31:0]           s_wdata_i,
    input  wire [3:0]            s_wstrb_i,
    input  wire                  s_wvalid_i,
    output wire                  s_wready_o,
    output reg  [1:0]            s_bresp_o,
    output reg                   s_bvalid_o,
    input  wire                  s_bready_i,
    input  wire [7:0]            s_araddr_i,
    input  wire                  s_arvalid_i,
    output wire                  s_arready_o,
    output reg  [31:0]           s_rdata_o,
    output reg  [1:0]            s_rresp_o,
    output reg                   s_rvalid_o,
    input  wire                  s_rready_i,

    // Status from the core
    input  wire                  busy_i,
    input  wire                  done_i,
    input  wire                  err_i,

    // Configuration and control to the core
    output reg  [8:0]            k_o,
    output reg  [15:0]           m_o,
    output reg  [4:0]            s_o,
    output reg  signed [7:0]     zp_o,
    output reg                   relu_o,
    output wire [32*N-1:0]       bias_o,
    output reg                   start_o,
    output reg                   soft_rst_o,
    output reg                   done_clr_o,
    output reg                   err_clr_o,
    output wire                  irq_o
);

reg [31:0] bias_r [0:N-1];
reg        irq_en_r;

// Handshakes: ready may depend on valid; one transaction at a time
wire wr_fire = s_awvalid_i && s_wvalid_i && !s_bvalid_o;
wire rd_fire = s_arvalid_i && !s_rvalid_o;
assign s_awready_o = wr_fire;
assign s_wready_o  = wr_fire;
assign s_arready_o = rd_fire;

wire [5:0] widx  = s_awaddr_i[7:2];
wire [5:0] ridx  = s_araddr_i[7:2];
wire       w_map = (widx <= 6'd6) || ((widx >= 6'd8) && (widx < 8 + N));
wire       r_map = (ridx <= 6'd6) || ((ridx >= 6'd8) && (ridx < 8 + N));

assign irq_o = done_i & irq_en_r;

genvar g;
generate
    for (g = 0; g < N; g = g + 1) begin : g_bias
        assign bias_o[32*g +: 32] = bias_r[g];
    end
endgenerate

integer i;

always @(posedge aclk_i) begin
    if (!aresetn_i) begin
        k_o        <= 9'd0;
        m_o        <= 16'd0;
        s_o        <= 5'd0;
        zp_o       <= 8'sd0;
        relu_o     <= 1'b0;
        irq_en_r   <= 1'b0;
        start_o    <= 1'b0;
        soft_rst_o <= 1'b0;
        done_clr_o <= 1'b0;
        err_clr_o  <= 1'b0;
        s_bvalid_o <= 1'b0;
        s_bresp_o  <= 2'b00;
        s_rvalid_o <= 1'b0;
        s_rresp_o  <= 2'b00;
        s_rdata_o  <= 32'd0;
        for (i = 0; i < N; i = i + 1) bias_r[i] <= 32'd0;
    end else begin
        // One-cycle pulses default to 0
        start_o    <= 1'b0;
        soft_rst_o <= 1'b0;
        done_clr_o <= 1'b0;
        err_clr_o  <= 1'b0;

        if (s_bvalid_o && s_bready_i) s_bvalid_o <= 1'b0;
        if (s_rvalid_o && s_rready_i) s_rvalid_o <= 1'b0;

        // Write
        if (wr_fire) begin
            s_bvalid_o <= 1'b1;
            s_bresp_o  <= w_map ? 2'b00 : 2'b10;
            if (w_map) begin
                case (widx)
                    6'd0: begin
                        relu_o     <= s_wdata_i[2];
                        soft_rst_o <= s_wdata_i[1];
                        start_o    <= s_wdata_i[0] & ~s_wdata_i[1];   // soft_reset wins
                    end
                    6'd1: begin
                        done_clr_o <= s_wdata_i[1];                   // W1C
                        err_clr_o  <= s_wdata_i[2];                   // W1C
                    end
                    6'd2: k_o      <= s_wdata_i[8:0];
                    6'd3: m_o      <= s_wdata_i[15:0];
                    6'd4: s_o      <= s_wdata_i[4:0];
                    6'd5: zp_o     <= s_wdata_i[7:0];
                    6'd6: irq_en_r <= s_wdata_i[0];
                    default: bias_r[widx - 6'd8] <= s_wdata_i;
                endcase
            end
        end

        // Read
        if (rd_fire) begin
            s_rvalid_o <= 1'b1;
            s_rresp_o  <= r_map ? 2'b00 : 2'b10;
            s_rdata_o  <= 32'd0;
            if (r_map) begin
                case (ridx)
                    6'd0: s_rdata_o <= {29'd0, relu_o, 2'b00};
                    6'd1: s_rdata_o <= {29'd0, err_i, done_i, busy_i};
                    6'd2: s_rdata_o <= {23'd0, k_o};
                    6'd3: s_rdata_o <= {16'd0, m_o};
                    6'd4: s_rdata_o <= {27'd0, s_o};
                    6'd5: s_rdata_o <= {24'd0, zp_o};
                    6'd6: s_rdata_o <= {31'd0, irq_en_r};
                    default: s_rdata_o <= bias_r[ridx - 6'd8];
                endcase
            end
        end
    end
end

endmodule : qsa_regs
