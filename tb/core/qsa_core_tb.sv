// Directed testbench for qsa_core (N=4)
// Expected outputs for the two jobs were produced by the independent Python golden model
// (python/qsa_model.py), not by the RTL or by this testbench.
module qsa_core_tb;

    localparam N = 4;

    reg                    clk, rst, soft_rst, start, done_clr, err_clr;
    reg  [8:0]             k;
    reg  [15:0]            m;
    reg  [4:0]             s;
    reg  signed [7:0]      zp;
    reg                    relu;
    reg  [32*N-1:0]        bias;
    reg                    s_tvalid, s_tlast;
    reg  [16*N-1:0]        s_tdata;
    reg                    m_tready;
    wire                   s_tready, m_tvalid, m_tlast, busy, done, err;
    wire [8*N-1:0]         m_tdata;

    reg signed [7:0]       Am   [0:N-1][0:5];
    reg signed [7:0]       Bm   [0:5][0:N-1];
    reg signed [7:0]       expo [0:N-1][0:N-1];
    reg [8*N-1:0]          got  [0:N-1];
    reg                    gtl  [0:N-1];
    integer                gcnt, rmode, checks, errors;

    qsa_core #(.N(N)) DUT (
        .clk_i(clk), .rst_i(rst), .soft_rst_i(soft_rst), .start_i(start),
        .done_clr_i(done_clr), .err_clr_i(err_clr),
        .k_i(k), .m_i(m), .s_i(s), .zp_i(zp), .relu_i(relu), .bias_i(bias),
        .s_tvalid_i(s_tvalid), .s_tready_o(s_tready), .s_tdata_i(s_tdata), .s_tlast_i(s_tlast),
        .m_tvalid_o(m_tvalid), .m_tready_i(m_tready), .m_tdata_o(m_tdata), .m_tlast_o(m_tlast),
        .busy_o(busy), .done_o(done), .err_len_o(err)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Output beat collector (samples the values the DUT sees at each rising edge)
    always @(posedge clk) begin
        if (m_tvalid && m_tready) begin
            if (gcnt < N) begin
                got[gcnt] = m_tdata;
                gtl[gcnt] = m_tlast;
            end
            gcnt = gcnt + 1;
        end
    end

    // Output backpressure: mode 0 = always ready, mode 1 = random stalls
    always @(negedge clk) begin
        if (rmode == 0) m_tready = 1'b1;
        else            m_tready = ($urandom_range(0, 2) != 0);
    end

    task load_job1;
        begin
            Am[0][0] = 47;
            Am[0][1] = -128;
            Am[0][2] = -103;
            Am[0][3] = -128;
            Am[1][0] = 127;
            Am[1][1] = 1;
            Am[1][2] = 127;
            Am[1][3] = -25;
            Am[2][0] = -36;
            Am[2][1] = -128;
            Am[2][2] = 0;
            Am[2][3] = -105;
            Am[3][0] = 127;
            Am[3][1] = -128;
            Am[3][2] = -18;
            Am[3][3] = 1;
            Bm[0][0] = -36;
            Bm[0][1] = 124;
            Bm[0][2] = 127;
            Bm[0][3] = -105;
            Bm[1][0] = -118;
            Bm[1][1] = 105;
            Bm[1][2] = -93;
            Bm[1][3] = 64;
            Bm[2][0] = -67;
            Bm[2][1] = 7;
            Bm[2][2] = 23;
            Bm[2][3] = -36;
            Bm[3][0] = 119;
            Bm[3][1] = 96;
            Bm[3][2] = 21;
            Bm[3][3] = -1;
            expo[0][0] = 10;
            expo[0][1] = -40;
            expo[0][2] = 25;
            expo[0][3] = -18;
            expo[1][0] = -32;
            expo[1][1] = 28;
            expo[1][2] = 36;
            expo[1][3] = -35;
            expo[2][0] = 8;
            expo[2][1] = -55;
            expo[2][2] = 10;
            expo[2][3] = -8;
            expo[3][0] = 23;
            expo[3][1] = 4;
            expo[3][2] = 54;
            expo[3][3] = -41;
            bias[32*0 +: 32] = 0;
            bias[32*1 +: 32] = 0;
            bias[32*2 +: 32] = 0;
            bias[32*3 +: 32] = 0;
            m = 1; s = 9; zp = 0; relu = 0;
        end
    endtask

    task load_job2;
        begin
            Am[0][0] = 122;
            Am[0][1] = -74;
            Am[0][2] = 1;
            Am[0][3] = 127;
            Am[0][4] = 87;
            Am[0][5] = 77;
            Am[1][0] = 50;
            Am[1][1] = -89;
            Am[1][2] = 0;
            Am[1][3] = 1;
            Am[1][4] = 12;
            Am[1][5] = 76;
            Am[2][0] = -49;
            Am[2][1] = 127;
            Am[2][2] = 8;
            Am[2][3] = 1;
            Am[2][4] = 38;
            Am[2][5] = -11;
            Am[3][0] = 70;
            Am[3][1] = 1;
            Am[3][2] = -84;
            Am[3][3] = 91;
            Am[3][4] = 7;
            Am[3][5] = 81;
            Bm[0][0] = 1;
            Bm[0][1] = 15;
            Bm[0][2] = 0;
            Bm[0][3] = -69;
            Bm[1][0] = -46;
            Bm[1][1] = -65;
            Bm[1][2] = 28;
            Bm[1][3] = 16;
            Bm[2][0] = 5;
            Bm[2][1] = -93;
            Bm[2][2] = -51;
            Bm[2][3] = 1;
            Bm[3][0] = 127;
            Bm[3][1] = 87;
            Bm[3][2] = 95;
            Bm[3][3] = 33;
            Bm[4][0] = -83;
            Bm[4][1] = 40;
            Bm[4][2] = -12;
            Bm[4][3] = 127;
            Bm[5][0] = 14;
            Bm[5][1] = -83;
            Bm[5][2] = -23;
            Bm[5][3] = -86;
            expo[0][0] = 25;
            expo[0][1] = 26;
            expo[0][2] = 16;
            expo[0][3] = 3;
            expo[1][0] = 12;
            expo[1][1] = 6;
            expo[1][2] = 0;
            expo[1][3] = 0;
            expo[2][0] = 0;
            expo[2][1] = 0;
            expo[2][2] = 10;
            expo[2][3] = 21;
            expo[3][0] = 22;
            expo[3][1] = 20;
            expo[3][2] = 22;
            expo[3][3] = 0;
            bias[32*0 +: 32] = 100;
            bias[32*1 +: 32] = -200;
            bias[32*2 +: 32] = 300;
            bias[32*3 +: 32] = -400;
            m = 3; s = 11; zp = 5; relu = 1;
        end
    endtask

    // Run one job: start pulse, K beats, wait for the core to return to idle.
    // badmode 0 = correct TLAST, 1 = TLAST early on beat 1, 2 = TLAST missing on last beat
    task do_job(input integer kk, input integer badmode);
        integer b, i, j, cyc;
        reg     stop;
        begin
            gcnt = 0;
            stop = 0;
            @(negedge clk);
            k = kk; start = 1;
            @(negedge clk);
            start = 0;
            for (b = 0; (b < kk) && !stop; b = b + 1) begin
                if (!s_tready) begin
                    errors = errors + 1;
                    $display("ERROR: s_tready low while loading, beat %0d", b);
                end
                s_tvalid = 1;
                for (i = 0; i < N; i = i + 1) s_tdata[8*i +: 8]       = Am[i][b];
                for (j = 0; j < N; j = j + 1) s_tdata[8*(N+j) +: 8]   = Bm[b][j];
                if (badmode == 1)      s_tlast = (b == 1);
                else if (badmode == 2) s_tlast = 1'b0;
                else                   s_tlast = (b == kk - 1);
                @(negedge clk);
                if (badmode == 1 && b == 1) stop = 1;
            end
            s_tvalid = 0; s_tlast = 0; s_tdata = 0;
            cyc = 0;
            while (busy && cyc < 400) begin
                @(negedge clk);
                cyc = cyc + 1;
            end
            if (busy) begin
                errors = errors + 1;
                $display("ERROR: timeout, core still busy");
            end
            @(negedge clk);
        end
    endtask

    task check_good(input [8*24:1] name);
        integer r, j;
        begin
            checks = checks + 1;
            if (gcnt != N) begin
                errors = errors + 1;
                $display("ERROR %0s: got %0d output beats, expected %0d", name, gcnt, N);
            end
            for (r = 0; r < N; r = r + 1) begin
                if (gtl[r] !== (r == N-1)) begin
                    errors = errors + 1;
                    $display("ERROR %0s: TLAST wrong on row %0d", name, r);
                end
                for (j = 0; j < N; j = j + 1) begin
                    checks = checks + 1;
                    if (got[r][8*j +: 8] !== expo[r][j]) begin
                        errors = errors + 1;
                        $display("ERROR %0s: C[%0d][%0d] got=%0d exp=%0d", name, r, j,
                                 $signed(got[r][8*j +: 8]), expo[r][j]);
                    end
                end
            end
            checks = checks + 4;
            if (done !== 1'b1)    begin errors = errors + 1; $display("ERROR %0s: done not set", name); end
            if (err  !== 1'b0)    begin errors = errors + 1; $display("ERROR %0s: err_len set", name); end
            if (busy !== 1'b0)    begin errors = errors + 1; $display("ERROR %0s: busy still set", name); end
            if (s_tready !== 1'b0) begin errors = errors + 1; $display("ERROR %0s: s_tready high when idle", name); end
        end
    endtask

    task check_err(input [8*24:1] name);
        begin
            checks = checks + 4;
            if (gcnt != 0)     begin errors = errors + 1; $display("ERROR %0s: output beats after error: %0d", name, gcnt); end
            if (err  !== 1'b1) begin errors = errors + 1; $display("ERROR %0s: err_len not set", name); end
            if (done !== 1'b0) begin errors = errors + 1; $display("ERROR %0s: done set", name); end
            if (busy !== 1'b0) begin errors = errors + 1; $display("ERROR %0s: busy set", name); end
        end
    endtask

    initial begin
        checks = 0; errors = 0; gcnt = 0; rmode = 0;
        rst = 1; soft_rst = 0; start = 0; done_clr = 0; err_clr = 0;
        k = 0; m = 0; s = 0; zp = 0; relu = 0; bias = 0;
        s_tvalid = 0; s_tlast = 0; s_tdata = 0; m_tready = 1;
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);

        checks = checks + 3;
        if (busy !== 1'b0 || done !== 1'b0 || err !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR: flags not clear after reset");
        end

        // Job 1: always-ready output
        load_job1;
        rmode = 0;
        do_job(4, 0);
        check_good("job1");

        // Clear done
        @(negedge clk); done_clr = 1;
        @(negedge clk); done_clr = 0;
        @(negedge clk);
        checks = checks + 1;
        if (done !== 1'b0) begin errors = errors + 1; $display("ERROR: done_clr did not clear done"); end

        // Job 2: relu, zero point, bias, random output stalls
        load_job2;
        rmode = 1;
        do_job(6, 0);
        check_good("job2 backpressure");

        // TLAST early (abort), then TLAST missing on the last beat (abort)
        load_job1;
        rmode = 0;
        do_job(4, 1);
        check_err("tlast early");
        do_job(4, 2);
        check_err("tlast missing");

        // Good job again: must be clean after the aborted jobs
        rmode = 1;
        do_job(4, 0);
        check_good("job1 after errors");

        // Illegal K: 0, then 257
        @(negedge clk); done_clr = 1;
        @(negedge clk); done_clr = 0;
        @(negedge clk); k = 9'd0; start = 1;
        @(negedge clk); start = 0;
        @(negedge clk);
        gcnt = 0;
        check_err("illegal K=0");
        @(negedge clk); err_clr = 1;
        @(negedge clk); err_clr = 0;
        @(negedge clk); k = 9'd257; start = 1;
        @(negedge clk); start = 0;
        @(negedge clk);
        check_err("illegal K=257");

        if (errors == 0)
            $display("*** CORE TEST PASSED *** checks=%0d errors=%0d", checks, errors);
        else
            $display("*** CORE TEST FAILED *** checks=%0d errors=%0d", checks, errors);
        $finish;
    end

    // Watchdog
    initial begin
        #2000000;
        $display("*** CORE TEST FAILED *** timeout");
        $finish;
    end

endmodule : qsa_core_tb
