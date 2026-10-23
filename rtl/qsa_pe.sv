// QSA processing element: signed INT8 multiply-accumulate with pass-through
module qsa_pe (
    input  wire                clk_i,
    input  wire                rst_i,    // synchronous reset
    input  wire                clr_i,    // clear accumulator (new job)
    input  wire                en_i,     // accumulate enable
    input  wire signed [7:0]   a_i,
    input  wire signed [7:0]   b_i,
    output reg  signed [7:0]   a_o,      // a passed to the right neighbour
    output reg  signed [7:0]   b_o,      // b passed to the lower neighbour
    output reg  signed [31:0]  acc_o
);

always @(posedge clk_i) begin
    if (rst_i || clr_i) begin
        a_o   <= 8'sd0;
        b_o   <= 8'sd0;
        acc_o <= 32'sd0;
    end else begin
        a_o <= a_i;
        b_o <= b_i;
        if (en_i)
            acc_o <= acc_o + (a_i * b_i);   // signed x signed
    end
end

endmodule : qsa_pe
