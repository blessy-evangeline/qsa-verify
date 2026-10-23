// Directed testbench for qsa_pe (hand-computed expected values)
module qsa_pe_tb;

    reg                clk, rst, clr, en;
    reg  signed [7:0]  a, b;
    wire signed [7:0]  a_o, b_o;
    wire signed [31:0] acc;
    integer            checks, errors;

    qsa_pe DUT (
        .clk_i(clk), .rst_i(rst), .clr_i(clr), .en_i(en),
        .a_i(a), .b_i(b), .a_o(a_o), .b_o(b_o), .acc_o(acc)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Apply one operation on a falling edge, check after the next rising edge
    task step(input signed [7:0] ta, input signed [7:0] tb_in,
              input te, input tc, input signed [31:0] expected);
        reg signed [7:0] exp_a, exp_b;
        begin
            @(negedge clk);
            a = ta; b = tb_in; en = te; clr = tc;
            @(posedge clk);
            #1;
            exp_a = tc ? 8'sd0 : ta;
            exp_b = tc ? 8'sd0 : tb_in;
            checks = checks + 3;
            if (acc !== expected) begin
                errors = errors + 1;
                $display("ERROR acc: a=%0d b=%0d en=%0b clr=%0b got=%0d exp=%0d", ta, tb_in, te, tc, acc, expected);
            end
            if (a_o !== exp_a) begin
                errors = errors + 1;
                $display("ERROR a_o: got=%0d exp=%0d", a_o, exp_a);
            end
            if (b_o !== exp_b) begin
                errors = errors + 1;
                $display("ERROR b_o: got=%0d exp=%0d", b_o, exp_b);
            end
        end
    endtask

    initial begin
        checks = 0; errors = 0;
        rst = 1; clr = 0; en = 0; a = 0; b = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        #1;
        checks = checks + 1;
        if (acc !== 32'sd0) begin
            errors = errors + 1;
            $display("ERROR: acc not zero after reset");
        end

        //   a      b    en clr  expected acc
        step(  3,    4,  1, 0,        12);   //  3*4
        step( -5,    7,  1, 0,       -23);   //  12 - 35
        step(-128, -128, 1, 0,     16361);   //  -23 + 16384
        step( 127, -128, 1, 0,       105);   //  16361 - 16256
        step( 100,  100, 0, 0,       105);   //  en=0: unchanged
        step(  5,    5,  1, 1,         0);   //  clr wins over en
        step( -1,   -1,  1, 0,         1);   //  0 + 1

        if (errors == 0)
            $display("*** PE TEST PASSED *** checks=%0d errors=%0d", checks, errors);
        else
            $display("*** PE TEST FAILED *** checks=%0d errors=%0d", checks, errors);
        $finish;
    end

endmodule : qsa_pe_tb
