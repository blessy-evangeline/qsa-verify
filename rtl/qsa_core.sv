// QSA core: control FSM + systolic array + per-column requantization
// Stream formats follow spec v1.0 (Sections 4 and 5). Configuration arrives on plain ports;
// the AXI4-Lite register block that drives them is a separate module added later.
//
// States: IDLE -> LOAD (accept K beats) -> WAIT (array drains) -> OUT (N rows) -> IDLE
// Invariant: array accumulators are cleared in IDLE and on the edge that ends a job,
// so they are zero whenever busy = 0.
// Drain wait is conservative: 2N cycles after the last beat (derived minimum is 2N-2).
module qsa_core #(
    parameter N = 4
) (
    input  wire                  clk_i,
    input  wire                  rst_i,          // hard reset (synchronous)
    input  wire                  soft_rst_i,     // soft reset: FSM to idle, flags cleared
    input  wire                  start_i,        // one-cycle start pulse
    input  wire                  done_clr_i,
    input  wire                  err_clr_i,

    input  wire [8:0]            k_i,
    input  wire [15:0]           m_i,
    input  wire [4:0]            s_i,
    input  wire signed [7:0]     zp_i,
    input  wire                  relu_i,
    input  wire [32*N-1:0]       bias_i,         // BIAS[j] = bias_i[32*j +: 32]

    // AXI4-Stream slave (input beats)
    input  wire                  s_tvalid_i,
    output wire                  s_tready_o,
    input  wire [16*N-1:0]       s_tdata_i,      // low 8N bits: A column, high 8N bits: B row
    input  wire                  s_tlast_i,

    // AXI4-Stream master (output rows)
    output wire                  m_tvalid_o,
    input  wire                  m_tready_i,
    output wire [8*N-1:0]        m_tdata_o,
    output wire                  m_tlast_o,

    output wire                  busy_o,
    output reg                   done_o,
    output reg                   err_len_o
);

localparam [1:0] S_IDLE = 2'd0,
                 S_LOAD = 2'd1,
                 S_WAIT = 2'd2,
                 S_OUT  = 2'd3;

localparam [7:0] WAIT_MAX = 2*N - 1;

reg [1:0]  state;
reg [8:0]  cnt;       // beats accepted so far
reg [7:0]  wcnt;      // drain wait counter
reg [7:0]  row;       // output row index

wire k_legal   = (k_i != 9'd0) && (k_i <= 9'd256);
wire [8:0] k_m1 = k_i - 9'd1;

assign s_tready_o = (state == S_LOAD);
assign m_tvalid_o = (state == S_OUT);
assign m_tlast_o  = m_tvalid_o && (row == N-1);   // TLAST only while a beat is valid
assign busy_o     = (state != S_IDLE);

wire accept   = s_tvalid_i && s_tready_o;
wire exp_last = (cnt == k_m1);
wire bad_last = accept && (s_tlast_i != exp_last);
wire out_fire = m_tvalid_o && m_tready_i;

// Clear the array while idle, on an aborted job, and on the edge that ends a job
wire clr_arr = (state == S_IDLE) || bad_last || (out_fire && m_tlast_o);

wire [32*N*N-1:0] acc_all;

qsa_array #(.N(N)) u_array (
    .clk_i   (clk_i),
    .rst_i   (rst_i | soft_rst_i),
    .clr_i   (clr_arr),
    .valid_i (accept),
    .a_i     (s_tdata_i[8*N-1:0]),
    .b_i     (s_tdata_i[16*N-1:8*N]),
    .acc_o   (acc_all)
);

// One requantization unit per output column, selecting the current row
genvar j;
generate
    for (j = 0; j < N; j = j + 1) begin : g_rq
        wire signed [31:0] acc_s = acc_all[32*(row*N + j) +: 32];
        wire signed [7:0]  y_s;
        qsa_requant u_rq (
            .acc_i  (acc_s),
            .bias_i (bias_i[32*j +: 32]),
            .m_i    (m_i),
            .s_i    (s_i),
            .zp_i   (zp_i),
            .relu_i (relu_i),
            .y_o    (y_s)
        );
        assign m_tdata_o[8*j +: 8] = y_s;
    end
endgenerate

// Control FSM
always @(posedge clk_i) begin
    if (rst_i || soft_rst_i) begin
        state     <= S_IDLE;
        cnt       <= 9'd0;
        wcnt      <= 8'd0;
        row       <= 8'd0;
        done_o    <= 1'b0;
        err_len_o <= 1'b0;
    end else begin
        if (done_clr_i) done_o    <= 1'b0;
        if (err_clr_i)  err_len_o <= 1'b0;

        case (state)
            S_IDLE: begin
                if (start_i) begin
                    if (k_legal) begin
                        state     <= S_LOAD;
                        cnt       <= 9'd0;
                        done_o    <= 1'b0;
                        err_len_o <= 1'b0;
                    end else begin
                        err_len_o <= 1'b1;     // illegal K: reject start
                    end
                end
            end

            S_LOAD: begin
                if (accept) begin
                    if (bad_last) begin
                        err_len_o <= 1'b1;     // TLAST wrong: abort job
                        state     <= S_IDLE;
                    end else if (exp_last) begin
                        state <= S_WAIT;
                        wcnt  <= 8'd0;
                    end else begin
                        cnt <= cnt + 9'd1;
                    end
                end
            end

            S_WAIT: begin
                if (wcnt == WAIT_MAX) begin
                    state <= S_OUT;
                    row   <= 8'd0;
                end else begin
                    wcnt <= wcnt + 8'd1;
                end
            end

            S_OUT: begin
                if (out_fire) begin
                    if (m_tlast_o) begin
                        state  <= S_IDLE;
                        done_o <= 1'b1;
                    end else begin
                        row <= row + 8'd1;
                    end
                end
            end
        endcase
    end
end

endmodule : qsa_core
