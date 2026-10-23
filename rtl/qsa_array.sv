// QSA systolic array: NxN output-stationary grid of qsa_pe with input skew
//
// Input per beat k (matches the spec stream layout):
//   a_i byte i = A[i][k]   (row i of the tile)
//   b_i byte j = B[k][j]   (column j of the tile)
// Row i of A is delayed i cycles and column j of B is delayed j cycles, so
// A[i][k] and B[k][j] meet in PE(i,j) on the same clock edge.
// When valid_i = 0 the array is fed zeros, so accumulators hold their value.
// Output: acc_o element (i,j) = acc_o[32*(i*N+j) +: 32]
module qsa_array #(
    parameter N = 4
) (
    input  wire                  clk_i,
    input  wire                  rst_i,     // synchronous reset
    input  wire                  clr_i,     // clear all accumulators and pipelines
    input  wire                  valid_i,   // a_i / b_i carry a real beat
    input  wire [8*N-1:0]        a_i,
    input  wire [8*N-1:0]        b_i,
    output wire [32*N*N-1:0]     acc_o
);

wire signed [7:0]  a_in [0:N-1];          // gated A input, not yet skewed
wire signed [7:0]  b_in [0:N-1];          // gated B input, not yet skewed
wire signed [7:0]  a_sk [0:N-1];          // A after row skew
wire signed [7:0]  b_sk [0:N-1];          // B after column skew
wire signed [7:0]  a_h  [0:N-1][0:N];     // a_h[i][j] = a input of PE(i,j)
wire signed [7:0]  b_v  [0:N][0:N-1];     // b_v[i][j] = b input of PE(i,j)
wire signed [31:0] acc_w [0:N-1][0:N-1];

genvar i, j;

generate
    // Row skew for A: row i delayed by i cycles
    for (i = 0; i < N; i = i + 1) begin : g_a_skew
        assign a_in[i] = valid_i ? a_i[8*i +: 8] : 8'sd0;
        if (i == 0) begin : g_no_delay
            assign a_sk[i] = a_in[i];
        end else begin : g_delay
            reg signed [7:0] dly [0:i-1];
            integer d;
            always @(posedge clk_i) begin
                if (rst_i || clr_i) begin
                    for (d = 0; d < i; d = d + 1) dly[d] <= 8'sd0;
                end else begin
                    dly[0] <= a_in[i];
                    for (d = 1; d < i; d = d + 1) dly[d] <= dly[d-1];
                end
            end
            assign a_sk[i] = dly[i-1];
        end
        assign a_h[i][0] = a_sk[i];
    end

    // Column skew for B: column j delayed by j cycles
    for (j = 0; j < N; j = j + 1) begin : g_b_skew
        assign b_in[j] = valid_i ? b_i[8*j +: 8] : 8'sd0;
        if (j == 0) begin : g_no_delay
            assign b_sk[j] = b_in[j];
        end else begin : g_delay
            reg signed [7:0] dly [0:j-1];
            integer d;
            always @(posedge clk_i) begin
                if (rst_i || clr_i) begin
                    for (d = 0; d < j; d = d + 1) dly[d] <= 8'sd0;
                end else begin
                    dly[0] <= b_in[j];
                    for (d = 1; d < j; d = d + 1) dly[d] <= dly[d-1];
                end
            end
            assign b_sk[j] = dly[j-1];
        end
        assign b_v[0][j] = b_sk[j];
    end

    // PE grid
    for (i = 0; i < N; i = i + 1) begin : g_row
        for (j = 0; j < N; j = j + 1) begin : g_col
            qsa_pe u_pe (
                .clk_i (clk_i),
                .rst_i (rst_i),
                .clr_i (clr_i),
                .en_i  (1'b1),
                .a_i   (a_h[i][j]),
                .b_i   (b_v[i][j]),
                .a_o   (a_h[i][j+1]),
                .b_o   (b_v[i+1][j]),
                .acc_o (acc_w[i][j])
            );
            assign acc_o[32*(i*N+j) +: 32] = acc_w[i][j];
        end
    end
endgenerate

endmodule : qsa_array
