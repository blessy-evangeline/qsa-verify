// Directed testbench for qsa_requant (hand-reasoned cases, cross-checked with a Python integer model)
module qsa_requant_tb;

    reg signed [31:0] acc, bias;
    reg        [15:0] m;
    reg        [4:0]  s;
    reg signed [7:0]  zp;
    reg               relu;
    wire signed [7:0] y;
    integer           checks, errors;

    qsa_requant DUT (
        .acc_i(acc), .bias_i(bias), .m_i(m), .s_i(s),
        .zp_i(zp), .relu_i(relu), .y_o(y)
    );

    task chk(input signed [31:0] t_acc, input signed [31:0] t_bias,
             input [15:0] t_m, input [4:0] t_s, input signed [7:0] t_zp,
             input t_relu, input signed [7:0] expected);
        begin
            acc = t_acc; bias = t_bias; m = t_m; s = t_s; zp = t_zp; relu = t_relu;
            #1;
            checks = checks + 1;
            if (y !== expected) begin
                errors = errors + 1;
                $display("ERROR case %0d: acc=%0d bias=%0d M=%0d S=%0d zp=%0d relu=%0b got=%0d exp=%0d",
                         checks, t_acc, t_bias, t_m, t_s, t_zp, t_relu, y, expected);
            end
        end
    endtask

    initial begin
        checks = 0; errors = 0;
        acc = 0; bias = 0; m = 0; s = 0; zp = 0; relu = 0;
        #1;

        //   acc          bias        M      S   zp   relu  exp
        chk(  100,           0,       1,     0,    0,  0,   100);   // plain pass-through
        chk( 1000,           0,       1,     3,    0,  0,   125);   // (1000+4)>>3
        chk(    4,           0,       1,     3,    0,  0,     1);   // exact tie +0.5 rounds up
        chk(   -4,           0,       1,     3,    0,  0,     0);   // exact tie -0.5 rounds up to 0
        chk(    3,           0,       1,     3,    0,  0,     0);   // just below tie
        chk( 1000,           0,       1,     0,    0,  0,   127);   // saturate high
        chk(-1000,           0,       1,     0,    0,  0,  -128);   // saturate low
        chk( -128,           0,       1,     0,    0,  0,  -128);   // exactly -128 must stay -128
        chk(  127,           0,       1,     0,    0,  0,   127);   // exactly 127
        chk(  128,           0,       1,     0,    0,  0,   127);   // 128 clamps to 127
        chk(   10,           0,       1,     0,  -20,  0,   -10);   // zero point added
        chk(   10,           0,       1,     0,  -20,  1,     0);   // relu after zero point
        chk(  100,           0,       1,     0,  100,  0,   127);   // zero point pushes past 127
        chk(   50,         -70,       1,     0,    0,  0,   -20);   // bias applied once
        chk(2000000000, 2000000000,   1,    31,    0,  0,     2);   // acc+bias must not wrap at 32 bits
        chk(    1,           0,   65535,    16,    0,  0,     1);   // max multiplier
        chk(-2000000000,     0,   65535,    31,    0,  0,  -128);   // large negative saturates low
        chk(   77,           0,       1,     0,    0,  1,    77);   // relu keeps positive
        chk(  -77,           0,       1,     0,    0,  1,     0);   // relu zeroes negative
        chk(-1000,           0,       1,     0,    0,  1,     0);   // saturate low then relu
        chk(  -10,           0,       1,     0,   20,  1,    10);   // relu must come after zero point
        chk(1073741824,      0,       1,    31,    0,  0,     1);   // tie at S=31
        chk(    1,           0,       1,     1,    0,  0,     1);   // S=1 tie +0.5
        chk(   -1,           0,       1,     1,    0,  0,     0);   // S=1 tie -0.5
        chk(  500,           0,       0,     0,    5,  0,     5);   // zero multiplier

        if (errors == 0)
            $display("*** REQUANT TEST PASSED *** checks=%0d errors=%0d", checks, errors);
        else
            $display("*** REQUANT TEST FAILED *** checks=%0d errors=%0d", checks, errors);
        $finish;
    end

endmodule : qsa_requant_tb
