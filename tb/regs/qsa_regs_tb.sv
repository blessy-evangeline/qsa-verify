// Directed testbench for qsa_regs (AXI4-Lite register block, N=4)
module qsa_regs_tb;

    localparam N = 4;

    reg         clk, aresetn;
    reg  [7:0]  awaddr, araddr;
    reg         awvalid, wvalid, bready, arvalid, rready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;
    reg         busy_i, done_i, err_i;

    wire [8:0]        k_o;
    wire [15:0]       m_o;
    wire [4:0]        s_o;
    wire signed [7:0] zp_o;
    wire              relu_o, start_o, soft_rst_o, done_clr_o, err_clr_o, irq_o;
    wire [32*N-1:0]   bias_o;

    integer checks, errors;
    integer cnt_start, cnt_soft, cnt_dclr, cnt_eclr;
    reg [31:0] rd;
    reg [1:0]  rsp;

    qsa_regs #(.N(N)) DUT (
        .aclk_i(clk), .aresetn_i(aresetn),
        .s_awaddr_i(awaddr), .s_awvalid_i(awvalid), .s_awready_o(awready),
        .s_wdata_i(wdata), .s_wstrb_i(wstrb), .s_wvalid_i(wvalid), .s_wready_o(wready),
        .s_bresp_o(bresp), .s_bvalid_o(bvalid), .s_bready_i(bready),
        .s_araddr_i(araddr), .s_arvalid_i(arvalid), .s_arready_o(arready),
        .s_rdata_o(rdata), .s_rresp_o(rresp), .s_rvalid_o(rvalid), .s_rready_i(rready),
        .busy_i(busy_i), .done_i(done_i), .err_i(err_i),
        .k_o(k_o), .m_o(m_o), .s_o(s_o), .zp_o(zp_o), .relu_o(relu_o), .bias_o(bias_o),
        .start_o(start_o), .soft_rst_o(soft_rst_o), .done_clr_o(done_clr_o),
        .err_clr_o(err_clr_o), .irq_o(irq_o)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Pulse counters (each pulse must last exactly one clock)
    always @(posedge clk) begin
        if (start_o)    cnt_start = cnt_start + 1;
        if (soft_rst_o) cnt_soft  = cnt_soft + 1;
        if (done_clr_o) cnt_dclr  = cnt_dclr + 1;
        if (err_clr_o)  cnt_eclr  = cnt_eclr + 1;
    end

    task clear_counts;
        begin
            cnt_start = 0; cnt_soft = 0; cnt_dclr = 0; cnt_eclr = 0;
        end
    endtask

    task axi_write(input [7:0] addr, input [31:0] data, output [1:0] resp);
        begin
            @(negedge clk);
            awaddr = addr; wdata = data; wstrb = 4'hF; awvalid = 1; wvalid = 1; bready = 0;
            @(negedge clk);
            awvalid = 0; wvalid = 0;
            if (!bvalid) begin
                errors = errors + 1;
                $display("ERROR: no BVALID after write to 0x%0h", addr);
            end
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
            if (!rvalid) begin
                errors = errors + 1;
                $display("ERROR: no RVALID after read of 0x%0h", addr);
            end
            data = rdata;
            resp = rresp;
            rready = 1;
            @(negedge clk);
            rready = 0;
        end
    endtask

    task chk(input [8*24:1] name, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("ERROR %0s: got=0x%0h exp=0x%0h", name, got, exp);
            end
        end
    endtask

    // Read a register and check data and an OKAY response
    task rd_chk(input [7:0] addr, input [8*24:1] name, input [31:0] exp);
        begin
            axi_read(addr, rd, rsp);
            chk(name, rd, exp);
            chk("resp OKAY", rsp, 2'b00);
        end
    endtask

    // Write a register and check an OKAY response
    task wr_ok(input [7:0] addr, input [31:0] data);
        begin
            axi_write(addr, data, rsp);
            chk("write resp OKAY", rsp, 2'b00);
        end
    endtask

    initial begin
        checks = 0; errors = 0;
        clear_counts;
        aresetn = 0; awaddr = 0; araddr = 0; awvalid = 0; wvalid = 0; bready = 0;
        arvalid = 0; rready = 0; wdata = 0; wstrb = 4'hF;
        busy_i = 0; done_i = 0; err_i = 0;
        repeat (3) @(negedge clk);
        aresetn = 1;
        @(negedge clk);

        // 1. Reset values
        rd_chk(8'h00, "CTRL reset",   0);
        rd_chk(8'h04, "STATUS reset", 0);
        rd_chk(8'h08, "K reset",      0);
        rd_chk(8'h0C, "QM reset",     0);
        rd_chk(8'h10, "QS reset",     0);
        rd_chk(8'h14, "ZP reset",     0);
        rd_chk(8'h18, "IRQ_EN reset", 0);
        rd_chk(8'h20, "BIAS0 reset",  0);
        rd_chk(8'h2C, "BIAS3 reset",  0);

        // 2. Write full-width ones: upper bits must read back as 0
        wr_ok(8'h08, 32'hFFFFFFFF);  rd_chk(8'h08, "K mask",      32'h1FF);
        wr_ok(8'h0C, 32'hFFFFFFFF);  rd_chk(8'h0C, "QM mask",     32'hFFFF);
        wr_ok(8'h10, 32'hFFFFFFFF);  rd_chk(8'h10, "QS mask",     32'h1F);
        wr_ok(8'h14, 32'hFFFFFFFF);  rd_chk(8'h14, "ZP mask",     32'hFF);
        wr_ok(8'h18, 32'hFFFFFFFF);  rd_chk(8'h18, "IRQ_EN mask", 32'h1);
        chk("k_o",  k_o,  32'h1FF);
        chk("m_o",  m_o,  32'hFFFF);
        chk("s_o",  s_o,  32'h1F);
        chk("zp_o", zp_o, 32'hFFFFFFFF);

        // 3. Bias registers
        wr_ok(8'h20, 32'hDEADBEEF);
        wr_ok(8'h2C, 32'h80000001);
        rd_chk(8'h20, "BIAS0 readback", 32'hDEADBEEF);
        rd_chk(8'h2C, "BIAS3 readback", 32'h80000001);
        rd_chk(8'h24, "BIAS1 untouched", 0);
        chk("bias_o[0]", bias_o[31:0],    32'hDEADBEEF);
        chk("bias_o[3]", bias_o[127:96],  32'h80000001);

        // 4. Address bits [1:0] are ignored
        rd_chk(8'h0B, "K misaligned", 32'h1FF);

        // 5. CTRL: relu readback, start and soft_reset pulses, soft_reset wins
        clear_counts;
        wr_ok(8'h00, 32'h5);
        chk("start pulses (write 0x5)", cnt_start, 1);
        chk("soft pulses (write 0x5)",  cnt_soft,  0);
        rd_chk(8'h00, "CTRL readback 0x4", 32'h4);
        chk("relu_o", relu_o, 1);
        clear_counts;
        wr_ok(8'h00, 32'h2);
        chk("start pulses (write 0x2)", cnt_start, 0);
        chk("soft pulses (write 0x2)",  cnt_soft,  1);
        rd_chk(8'h00, "CTRL readback 0x0", 32'h0);
        clear_counts;
        wr_ok(8'h00, 32'h3);
        chk("start pulses (write 0x3)", cnt_start, 0);
        chk("soft pulses (write 0x3)",  cnt_soft,  1);

        // 6. STATUS: read-only busy, write-1-to-clear done and err_len
        busy_i = 1; done_i = 1; err_i = 1;
        rd_chk(8'h04, "STATUS 0x7", 32'h7);
        clear_counts;
        wr_ok(8'h04, 32'h1);
        chk("dclr (write busy bit)", cnt_dclr, 0);
        chk("eclr (write busy bit)", cnt_eclr, 0);
        wr_ok(8'h04, 32'h0);
        chk("dclr (write 0)", cnt_dclr, 0);
        chk("eclr (write 0)", cnt_eclr, 0);
        wr_ok(8'h04, 32'h2);
        chk("dclr (write done bit)", cnt_dclr, 1);
        chk("eclr (write done bit)", cnt_eclr, 0);
        wr_ok(8'h04, 32'h4);
        chk("dclr (write err bit)", cnt_dclr, 1);
        chk("eclr (write err bit)", cnt_eclr, 1);
        rd_chk(8'h04, "STATUS still 0x7", 32'h7);

        // 7. Interrupt: irq = done AND irq_en
        @(negedge clk);
        chk("irq done=1 en=1", irq_o, 1);
        done_i = 0;
        @(negedge clk);
        chk("irq done=0 en=1", irq_o, 0);
        done_i = 1;
        wr_ok(8'h18, 32'h0);
        @(negedge clk);
        chk("irq done=1 en=0", irq_o, 0);

        // 8. Unmapped addresses: SLVERR, reads return 0, writes have no effect
        axi_read(8'h1C, rd, rsp);  chk("read 0x1C resp", rsp, 2'b10);  chk("read 0x1C data", rd, 0);
        axi_read(8'h30, rd, rsp);  chk("read 0x30 resp", rsp, 2'b10);  chk("read 0x30 data", rd, 0);
        axi_read(8'hFC, rd, rsp);  chk("read 0xFC resp", rsp, 2'b10);  chk("read 0xFC data", rd, 0);
        axi_write(8'h1C, 32'h12345, rsp);  chk("write 0x1C resp", rsp, 2'b10);
        axi_write(8'h30, 32'h12345, rsp);  chk("write 0x30 resp", rsp, 2'b10);
        rd_chk(8'h08, "K unchanged by bad write", 32'h1FF);

        // 9. Hard reset returns everything to reset values
        @(negedge clk); aresetn = 0;
        repeat (2) @(negedge clk);
        aresetn = 1;
        @(negedge clk);
        rd_chk(8'h08, "K after reset",    0);
        rd_chk(8'h0C, "QM after reset",   0);
        rd_chk(8'h20, "BIAS0 after reset", 0);
        rd_chk(8'h18, "IRQ_EN after reset", 0);

        if (errors == 0)
            $display("*** REGS TEST PASSED *** checks=%0d errors=%0d", checks, errors);
        else
            $display("*** REGS TEST FAILED *** checks=%0d errors=%0d", checks, errors);
        $finish;
    end

    // Watchdog
    initial begin
        #2000000;
        $display("*** REGS TEST FAILED *** timeout");
        $finish;
    end

endmodule : qsa_regs_tb
