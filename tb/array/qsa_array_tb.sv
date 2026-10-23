// Directed + random testbench for qsa_array (N=2 with a hand-computed case, N=4 random)
// The expected tile is computed by plain nested loops, independent of the RTL.

//------------------------------------------
// Checker: one DUT of size N, K beats per job
//------------------------------------------
module qsa_array_chk #(
    parameter N     = 2,
    parameter K     = 3,
    parameter TESTS = 10,
    parameter HAND  = 0      // 1 = also run the hand-computed 2x2 case (needs N=2, K=3)
) (
    output reg         done,
    output integer     errors_o,
    output integer     checks_o
);

    reg                 clk, rst, clr, valid;
    reg  [8*N-1:0]      a, b;
    wire [32*N*N-1:0]   acc;

    reg signed [7:0]    Am   [0:N-1][0:K-1];
    reg signed [7:0]    Bm   [0:K-1][0:N-1];
    integer             expc [0:N-1][0:N-1];
    integer             t, i, j, k;

    qsa_array #(.N(N)) DUT (
        .clk_i(clk), .rst_i(rst), .clr_i(clr), .valid_i(valid),
        .a_i(a), .b_i(b), .acc_o(acc)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Random INT8 value, biased toward the extremes
    function automatic signed [7:0] rnd8();
        integer r;
        begin
            r = $urandom_range(0, 9);
            case (r)
                0: rnd8 = -128;
                1: rnd8 = 127;
                2: rnd8 = -1;
                3: rnd8 = 0;
                4: rnd8 = 1;
                default: rnd8 = $urandom_range(0, 255);
            endcase
        end
    endfunction

    // Reference model: C = A x B with plain loops
    task compute_exp;
        integer ii, jj, kk;
        begin
            for (ii = 0; ii < N; ii = ii + 1)
                for (jj = 0; jj < N; jj = jj + 1) begin
                    expc[ii][jj] = 0;
                    for (kk = 0; kk < K; kk = kk + 1)
                        expc[ii][jj] = expc[ii][jj] + Am[ii][kk] * Bm[kk][jj];
                end
        end
    endtask

    // Clear, stream K beats, then wait for the array to drain
    task run_job;
        integer ii, jj, kk;
        begin
            @(negedge clk);
            clr = 1; valid = 0; a = 0; b = 0;
            @(negedge clk);
            clr = 0;
            for (kk = 0; kk < K; kk = kk + 1) begin
                @(negedge clk);
                valid = 1;
                for (ii = 0; ii < N; ii = ii + 1) a[8*ii +: 8] = Am[ii][kk];
                for (jj = 0; jj < N; jj = jj + 1) b[8*jj +: 8] = Bm[kk][jj];
            end
            @(negedge clk);
            valid = 0; a = 0; b = 0;
            repeat (2*N + 2) @(negedge clk);
        end
    endtask

    task check_job;
        integer ii, jj;
        reg signed [31:0] got;
        begin
            for (ii = 0; ii < N; ii = ii + 1)
                for (jj = 0; jj < N; jj = jj + 1) begin
                    got = acc[32*(ii*N+jj) +: 32];
                    checks_o = checks_o + 1;
                    if (got !== expc[ii][jj]) begin
                        errors_o = errors_o + 1;
                        $display("ERROR N=%0d C[%0d][%0d] got=%0d exp=%0d", N, ii, jj, got, expc[ii][jj]);
                    end
                end
        end
    endtask

    initial begin
        done = 0; errors_o = 0; checks_o = 0;
        rst = 1; clr = 0; valid = 0; a = 0; b = 0;
        repeat (2) @(negedge clk);
        rst = 0;

        if (HAND) begin
            // A = [1 2 3; 4 5 6]   B = [7 8; 9 10; 11 12]
            // C = [58 64; 139 154]  (computed by hand)
            Am[0][0] = 1; Am[0][1] = 2; Am[0][2] = 3;
            Am[1][0] = 4; Am[1][1] = 5; Am[1][2] = 6;
            Bm[0][0] = 7;  Bm[0][1] = 8;
            Bm[1][0] = 9;  Bm[1][1] = 10;
            Bm[2][0] = 11; Bm[2][1] = 12;
            compute_exp;
            run_job;
            check_job;
            checks_o = checks_o + 4;
            if ($signed(acc[ 0 +: 32]) !== 58)  begin errors_o = errors_o + 1; $display("ERROR hand C[0][0]"); end
            if ($signed(acc[32 +: 32]) !== 64)  begin errors_o = errors_o + 1; $display("ERROR hand C[0][1]"); end
            if ($signed(acc[64 +: 32]) !== 139) begin errors_o = errors_o + 1; $display("ERROR hand C[1][0]"); end
            if ($signed(acc[96 +: 32]) !== 154) begin errors_o = errors_o + 1; $display("ERROR hand C[1][1]"); end
        end

        for (t = 0; t < TESTS; t = t + 1) begin
            for (i = 0; i < N; i = i + 1)
                for (k = 0; k < K; k = k + 1) Am[i][k] = rnd8();
            for (k = 0; k < K; k = k + 1)
                for (j = 0; j < N; j = j + 1) Bm[k][j] = rnd8();
            compute_exp;
            run_job;
            check_job;
        end
        done = 1;
    end

endmodule : qsa_array_chk

//------------------------------------------
// Top
//------------------------------------------
module qsa_array_tb;

    wire done2, done4;
    wire signed [31:0] err2, chk2, err4, chk4;

    qsa_array_chk #(.N(2), .K(3), .TESTS(30), .HAND(1)) u_chk2 (
        .done(done2), .errors_o(err2), .checks_o(chk2)
    );

    qsa_array_chk #(.N(4), .K(8), .TESTS(50), .HAND(0)) u_chk4 (
        .done(done4), .errors_o(err4), .checks_o(chk4)
    );

    initial begin
        wait (done2 && done4);
        if ((err2 + err4) == 0 && (chk2 + chk4) > 0)
            $display("*** ARRAY TEST PASSED *** checks=%0d errors=%0d", chk2 + chk4, err2 + err4);
        else
            $display("*** ARRAY TEST FAILED *** checks=%0d errors=%0d", chk2 + chk4, err2 + err4);
        $finish;
    end

    // Watchdog
    initial begin
        #1000000;
        $display("*** ARRAY TEST FAILED *** timeout");
        $finish;
    end

endmodule : qsa_array_tb
