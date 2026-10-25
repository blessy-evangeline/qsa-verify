// End-to-end testbench for qsa_top (N=4)
// Program registers over AXI4-Lite, stream a job over AXI4-Stream, wait for irq,
// read STATUS, compare outputs. Expected values come from the Python golden model.
module qsa_top_tb;

    localparam N = 4;

    reg                clk, aresetn;
    reg  [7:0]         awaddr, araddr;
    reg                awvalid, wvalid, bready, arvalid, rready;
    reg  [31:0]        wdata;
    reg  [3:0]         wstrb;
    wire               awready, wready, bvalid, arready, rvalid;
    wire [1:0]         bresp, rresp;
    wire [31:0]        rdata;
    reg  [16*N-1:0]    s_tdata;
    reg                s_tvalid, s_tlast, m_tready;
    wire               s_tready, m_tvalid, m_tlast, irq;
    wire [8*N-1:0]     m_tdata;

    reg signed [7:0]   Am   [0:N-1][0:5];
    reg signed [7:0]   Bm   [0:5][0:N-1];
    reg signed [7:0]   expo [0:N-1][0:N-1];
    reg [8*N-1:0]      got  [0:N-1];
    reg                gtl  [0:N-1];
    integer            pk, pm, ps, pzp, prelu, pb0, pb1, pb2, pb3;
    integer            gcnt, rmode, checks, errors;
    reg [31:0]         rd;
    reg [1:0]          rsp;

    qsa_top #(.N(N)) DUT (
        .aclk(clk), .aresetn(aresetn),
        .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
        .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
        .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
        .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
        .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
        .s_axis_tdata(s_tdata), .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready), .s_axis_tlast(s_tlast),
        .m_axis_tdata(m_tdata), .m_axis_tvalid(m_tvalid), .m_axis_tready(m_tready), .m_axis_tlast(m_tlast),
        .irq(irq)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Output beat collector
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
            pk = 4; pm = 1; ps = 9; pzp = 0; prelu = 0;
            pb0 = 0;
            pb1 = 0;
            pb2 = 0;
            pb3 = 0;
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
            pk = 6; pm = 3; ps = 11; pzp = 5; prelu = 1;
            pb0 = 100;
            pb1 = -200;
            pb2 = 300;
            pb3 = -400;
        end
    endtask

    task axi_write(input [7:0] addr, input [31:0] data, output [1:0] resp);
        begin
            @(negedge clk);
            awaddr = addr; wdata = data; wstrb = 4'hF; awvalid = 1; wvalid = 1; bready = 0;
            @(negedge clk);
            awvalid = 0; wvalid = 0;
            if (!bvalid) begin errors = errors + 1; $display("ERROR: no BVALID after write to 0x%0h", addr); end
            resp = bresp;
            bready = 1;
            @(negedge clk);
            bready = 0;
        end
    endtask

    task axi_read(input [7:0] addr, output [31:0] data, output [1:0] resp);
        begin
            @(negedge clk);
            araddr = addr; arvalid = 1; rready = 0;
            @(negedge clk);
            arvalid = 0;
            if (!rvalid) begin errors = errors + 1; $display("ERROR: no RVALID after read of 0x%0h", addr); end
            data = rdata;
            resp = rresp;
            rready = 1;
            @(negedge clk);
            rready = 0;
        end
    endtask

    task chk(input [8*24:1] name, input [31:0] got_v, input [31:0] exp_v);
        begin
            checks = checks + 1;
            if (got_v !== exp_v) begin
                errors = errors + 1;
                $display("ERROR %0s: got=0x%0h exp=0x%0h", name, got_v, exp_v);
            end
        end
    endtask

    // Program K, QM, QS, ZP, BIAS and IRQ_EN over AXI4-Lite
    task program_regs;
        begin
            axi_write(8'h08, pk,  rsp);
            axi_write(8'h0C, pm,  rsp);
            axi_write(8'h10, ps,  rsp);
            axi_write(8'h14, pzp, rsp);
            axi_write(8'h20, pb0, rsp);
            axi_write(8'h24, pb1, rsp);
            axi_write(8'h28, pb2, rsp);
            axi_write(8'h2C, pb3, rsp);
            axi_write(8'h18, 32'h1, rsp);
        end
    endtask

    // One AXI4-Stream beat: hold valid until the DUT accepts it
    task send_beat(input integer b, input tl);
        integer i, j;
        reg acc;
        begin
            @(negedge clk);
            s_tvalid = 1;
            for (i = 0; i < N; i = i + 1) s_tdata[8*i +: 8]     = Am[i][b];
            for (j = 0; j < N; j = j + 1) s_tdata[8*(N+j) +: 8] = Bm[b][j];
            s_tlast = tl;
            acc = 0;
            while (!acc) begin
                @(posedge clk);
                if (s_tready) acc = 1;
            end
        end
    endtask

    // Full job: program registers, start, stream K beats, wait for the outcome
    // badmode 0 = correct TLAST, 2 = TLAST missing on the last beat
    task run_e2e(input integer badmode);
        integer b, cyc;
        begin
            gcnt = 0;
            program_regs;
            axi_write(8'h00, prelu ? 32'h5 : 32'h1, rsp);
            for (b = 0; b < pk; b = b + 1)
                send_beat(b, (badmode == 2) ? 1'b0 : (b == pk - 1));
            @(negedge clk);
            s_tvalid = 0; s_tlast = 0; s_tdata = 0;
            if (badmode == 0) begin
                cyc = 0;
                while (!irq && cyc < 800) begin
                    @(negedge clk);
                    cyc = cyc + 1;
                end
                if (!irq) begin errors = errors + 1; $display("ERROR: timeout waiting for irq"); end
            end else begin
                repeat (30) @(negedge clk);
            end
            repeat (2) @(negedge clk);
        end
    endtask

    task check_good(input [8*24:1] name);
        integer r, j;
        begin
            axi_read(8'h04, rd, rsp);
            chk("STATUS done only", rd, 32'h2);
            chk("irq high", irq, 1);
            chk("beat count", gcnt, N);
            for (r = 0; r < N; r = r + 1) begin
                chk("TLAST position", gtl[r], (r == N-1));
                for (j = 0; j < N; j = j + 1) begin
                    checks = checks + 1;
                    if (got[r][8*j +: 8] !== expo[r][j]) begin
                        errors = errors + 1;
                        $display("ERROR %0s: C[%0d][%0d] got=%0d exp=%0d", name, r, j,
                                 $signed(got[r][8*j +: 8]), expo[r][j]);
                    end
                end
            end
            // Clear done (write 1 to clear) and confirm
            axi_write(8'h04, 32'h2, rsp);
            repeat (3) @(negedge clk);
            axi_read(8'h04, rd, rsp);
            chk("STATUS after W1C", rd, 32'h0);
            chk("irq low", irq, 0);
        end
    endtask

    task check_err(input [8*24:1] name);
        begin
            axi_read(8'h04, rd, rsp);
            chk("STATUS err only", rd, 32'h4);
            chk("irq stays low", irq, 0);
            chk("no output beats", gcnt, 0);
            axi_write(8'h04, 32'h4, rsp);
            repeat (3) @(negedge clk);
            axi_read(8'h04, rd, rsp);
            chk("STATUS after err W1C", rd, 32'h0);
        end
    endtask

    initial begin
        checks = 0; errors = 0; gcnt = 0; rmode = 0;
        aresetn = 0; awaddr = 0; araddr = 0; awvalid = 0; wvalid = 0; bready = 0;
        arvalid = 0; rready = 0; wdata = 0; wstrb = 4'hF;
        s_tdata = 0; s_tvalid = 0; s_tlast = 0; m_tready = 1;
        repeat (3) @(negedge clk);
        aresetn = 1;
        @(negedge clk);

        // Job 1: always-ready output
        load_job1; rmode = 0;
        run_e2e(0);
        check_good("e2e job1");

        // Job 2: relu, zero point, bias, random output stalls
        load_job2; rmode = 1;
        run_e2e(0);
        check_good("e2e job2");

        // TLAST missing: job aborts with err_len, no output
        load_job1; rmode = 0;
        run_e2e(2);
        check_err("e2e tlast missing");

        // Recovery: same job again must be clean
        rmode = 1;
        run_e2e(0);
        check_good("e2e after error");

        // Illegal K = 0 programmed over AXI4-Lite
        axi_write(8'h08, 32'h0, rsp);
        axi_write(8'h00, 32'h1, rsp);
        repeat (5) @(negedge clk);
        gcnt = 0;
        check_err("e2e illegal K");

        if (errors == 0)
            $display("*** TOP TEST PASSED *** checks=%0d errors=%0d", checks, errors);
        else
            $display("*** TOP TEST FAILED *** checks=%0d errors=%0d", checks, errors);
        $finish;
    end

    // Watchdog
    initial begin
        #3000000;
        $display("*** TOP TEST FAILED *** timeout");
        $finish;
    end

endmodule : qsa_top_tb
