// Signed INT8 MAC UVM Testbench (ALU-sample style)
`include "uvm_macros.svh"
import uvm_pkg::*;

//------------------------------------------
// Interface (defined first)
//------------------------------------------
interface mac_if (input bit clk);
    logic                rst_i;
    logic                clr_i;
    logic                en_i;
    logic signed [7:0]   a_i;
    logic signed [7:0]   b_i;
    logic signed [31:0]  acc_o;
    logic                valid;   // TB-only flag: marks a driven transaction
endinterface : mac_if

//------------------------------------------
// DUT: acc = acc + a*b (signed INT8, INT32 accumulator)
//------------------------------------------
module mac_unit (
    input  wire                clk_i,
    input  wire                rst_i,
    input  wire                clr_i,
    input  wire                en_i,
    input  wire signed [7:0]   a_i,
    input  wire signed [7:0]   b_i,
    output logic signed [31:0] acc_o
);
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i)
            acc_o <= 32'sd0;
        else if (clr_i)
            acc_o <= 32'sd0;
        else if (en_i)
            acc_o <= acc_o + (a_i * b_i);   // signed x signed, sign-extended to 32 bits
    end
endmodule : mac_unit

//------------------------------------------
// Transaction
//------------------------------------------
class mac_seq_item extends uvm_sequence_item;

    rand bit signed [7:0]  a_i;
    rand bit signed [7:0]  b_i;
    rand bit               en_i;
    rand bit               clr_i;
    bit signed [31:0]      acc_o;
    rand int               wait_cycles;

    `uvm_object_utils_begin(mac_seq_item)
        `uvm_field_int(a_i, UVM_DEFAULT)
        `uvm_field_int(b_i, UVM_DEFAULT)
        `uvm_field_int(en_i, UVM_DEFAULT)
        `uvm_field_int(clr_i, UVM_DEFAULT)
        `uvm_field_int(acc_o, UVM_DEFAULT)
    `uvm_object_utils_end

    //------------------------------------------
    // Constraints (bias toward INT8 extremes)
    //------------------------------------------
    constraint delay_loops {wait_cycles inside {[0:3]};}
    constraint operand_a {a_i dist {-128 := 10, 127 := 10, -1 := 5, 0 := 5, 1 := 5, [-127:126] :/ 25};}
    constraint operand_b {b_i dist {-128 := 10, 127 := 10, -1 := 5, 0 := 5, 1 := 5, [-127:126] :/ 25};}
    constraint enable_c  {en_i  dist {1 := 9, 0 := 1};}
    constraint clear_c   {clr_i dist {0 := 9, 1 := 1};}

    function new (string name = "mac_seq_item");
        super.new(name);
    endfunction: new

endclass: mac_seq_item

//------------------------------------------
// Sequence
//------------------------------------------
class mac_base_seq extends uvm_sequence#(mac_seq_item);
    `uvm_object_utils(mac_base_seq)

    rand int unsigned num_of_ops;
    constraint num_of_ops_con {num_of_ops inside {[30:50]};}

    function new(string name = "mac_base_seq");
        super.new(name);
    endfunction: new

    task body();
        mac_seq_item m_mac_seq_item_h;
        repeat (num_of_ops) begin
            m_mac_seq_item_h = mac_seq_item::type_id::create("m_mac_seq_item_h");
            start_item(m_mac_seq_item_h);
            if (!m_mac_seq_item_h.randomize()) begin
                `uvm_error("mac_base_seq", "Randomize failed.")
            end
            finish_item(m_mac_seq_item_h);
        end
    endtask: body
endclass: mac_base_seq

//------------------------------------------
// Driver
//------------------------------------------
class mac_driver extends uvm_driver#(mac_seq_item);
    `uvm_component_utils(mac_driver)

    virtual mac_if m_mac_vif_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual mac_if)::get(this, "", "mac_if", m_mac_vif_h))
            `uvm_fatal("DRIVER", "Unable to get mac_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        mac_seq_item m_req_h;

        m_mac_vif_h.a_i   = 8'sd0;
        m_mac_vif_h.b_i   = 8'sd0;
        m_mac_vif_h.en_i  = 1'b0;
        m_mac_vif_h.clr_i = 1'b0;
        m_mac_vif_h.valid = 1'b0;

        // Reset sequence
        m_mac_vif_h.rst_i = 1'b1;
        repeat (2) @(posedge m_mac_vif_h.clk);
        @(negedge m_mac_vif_h.clk);
        m_mac_vif_h.rst_i = 1'b0;

        forever begin
            seq_item_port.get_next_item(m_req_h);
            @(negedge m_mac_vif_h.clk);
            m_mac_vif_h.a_i   = m_req_h.a_i;
            m_mac_vif_h.b_i   = m_req_h.b_i;
            m_mac_vif_h.en_i  = m_req_h.en_i;
            m_mac_vif_h.clr_i = m_req_h.clr_i;
            m_mac_vif_h.valid = 1'b1;
            `uvm_info("DRIVER", $sformatf("a=%0d b=%0d en=%0b clr=%0b", m_req_h.a_i, m_req_h.b_i, m_req_h.en_i, m_req_h.clr_i), UVM_MEDIUM)
            @(negedge m_mac_vif_h.clk);
            m_mac_vif_h.en_i  = 1'b0;     // item lasts exactly one clock edge
            m_mac_vif_h.clr_i = 1'b0;
            m_mac_vif_h.valid = 1'b0;
            repeat (m_req_h.wait_cycles) @(negedge m_mac_vif_h.clk);
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: mac_driver

//------------------------------------------
// Monitor
//------------------------------------------
class mac_monitor extends uvm_monitor;
    `uvm_component_utils(mac_monitor)

    virtual mac_if m_mac_vif_h;
    uvm_analysis_port #(mac_seq_item) m_analysis_port_h;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_analysis_port_h = new("m_analysis_port_h", this);
        if (!uvm_config_db#(virtual mac_if)::get(this, "", "mac_if", m_mac_vif_h))
            `uvm_fatal("MONITOR", "Unable to get mac_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        mac_seq_item m_req_h;
        @(negedge m_mac_vif_h.rst_i);
        forever begin
            @(posedge m_mac_vif_h.clk);
            if (m_mac_vif_h.valid === 1'b1) begin
                // New object per sample (never reuse one handle)
                m_req_h = mac_seq_item::type_id::create("m_mon_item");
                m_req_h.a_i   = m_mac_vif_h.a_i;
                m_req_h.b_i   = m_mac_vif_h.b_i;
                m_req_h.en_i  = m_mac_vif_h.en_i;
                m_req_h.clr_i = m_mac_vif_h.clr_i;
                @(posedge m_mac_vif_h.clk);   // result of the previous edge is now visible
                m_req_h.acc_o = m_mac_vif_h.acc_o;
                `uvm_info("MONITOR", $sformatf("a=%0d b=%0d en=%0b clr=%0b acc=%0d", m_req_h.a_i, m_req_h.b_i, m_req_h.en_i, m_req_h.clr_i, m_req_h.acc_o), UVM_MEDIUM)
                m_analysis_port_h.write(m_req_h);
            end
        end
    endtask: run_phase
endclass: mac_monitor

//------------------------------------------
// Agent
//------------------------------------------
class mac_agent extends uvm_agent;
    `uvm_component_utils(mac_agent)

    uvm_analysis_port #(mac_seq_item) m_analysis_port_h;
    uvm_sequencer #(mac_seq_item)     m_sequencer_h;
    mac_driver                        m_driver_h;
    mac_monitor                       m_monitor_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor_h       = mac_monitor::type_id::create("m_monitor_h", this);
        m_analysis_port_h = new("m_analysis_port_h", this);
        m_driver_h        = mac_driver::type_id::create("m_driver_h", this);
        m_sequencer_h     = uvm_sequencer#(mac_seq_item)::type_id::create("m_sequencer_h", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_monitor_h.m_analysis_port_h.connect(m_analysis_port_h);
        m_driver_h.seq_item_port.connect(m_sequencer_h.seq_item_export);
    endfunction: connect_phase
endclass: mac_agent

//------------------------------------------
// Scoreboard (reference model: signed MAC)
//------------------------------------------
class mac_scoreboard extends uvm_component;
    `uvm_component_utils(mac_scoreboard)

    uvm_tlm_analysis_fifo #(mac_seq_item) m_mac_fifo_h;
    bit signed [31:0] m_exp_acc;
    int unsigned      m_checks;
    int unsigned      m_errors;

    function new(string name = "mac_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_mac_fifo_h = new("m_mac_fifo_h", this);
        m_exp_acc    = 32'sd0;   // DUT is reset before the first transaction
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        mac_seq_item mac_op;
        forever begin
            m_mac_fifo_h.get(mac_op);
            if (mac_op.clr_i)
                m_exp_acc = 32'sd0;
            else if (mac_op.en_i)
                m_exp_acc = m_exp_acc + ($signed(mac_op.a_i) * $signed(mac_op.b_i));
            m_checks++;
            if (mac_op.acc_o === m_exp_acc) begin
                `uvm_info("SCOREBOARD", $sformatf("CHECK_OK a=%0d b=%0d acc=%0d", mac_op.a_i, mac_op.b_i, mac_op.acc_o), UVM_LOW)
            end else begin
                m_errors++;
                `uvm_error("SCOREBOARD", $sformatf("CHECK_FAILED a=%0d b=%0d en=%0b clr=%0b acc=%0d exp=%0d", mac_op.a_i, mac_op.b_i, mac_op.en_i, mac_op.clr_i, mac_op.acc_o, m_exp_acc))
            end
        end
    endtask: run_phase

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (m_errors == 0 && m_checks > 0)
            `uvm_info("SCOREBOARD", $sformatf("*** TEST PASSED *** checks=%0d errors=%0d", m_checks, m_errors), UVM_NONE)
        else
            `uvm_info("SCOREBOARD", $sformatf("*** TEST FAILED *** checks=%0d errors=%0d", m_checks, m_errors), UVM_NONE)
    endfunction: report_phase
endclass: mac_scoreboard

//------------------------------------------
// Environment
//------------------------------------------
class mac_env extends uvm_env;
    `uvm_component_utils(mac_env)

    mac_agent      m_mac_agent_h;
    mac_scoreboard m_scoreboard_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_mac_agent_h  = mac_agent::type_id::create("m_mac_agent_h", this);
        m_scoreboard_h = mac_scoreboard::type_id::create("m_scoreboard_h", this);
    endfunction: build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_mac_agent_h.m_analysis_port_h.connect(m_scoreboard_h.m_mac_fifo_h.analysis_export);
    endfunction: connect_phase
endclass: mac_env

//------------------------------------------
// Test
//------------------------------------------
class mac_base_test extends uvm_test;
    `uvm_component_utils(mac_base_test)

    mac_env m_mac_env_h;

    function new(string name = "mac_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_mac_env_h = mac_env::type_id::create("m_mac_env_h", this);
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        mac_base_seq m_mac_seq_h;
        phase.raise_objection(this);
        m_mac_seq_h = mac_base_seq::type_id::create("m_mac_seq_h");
        if (!m_mac_seq_h.randomize()) `uvm_error("mac_base_test", "Sequence randomize failed.")
        m_mac_seq_h.start(m_mac_env_h.m_mac_agent_h.m_sequencer_h);
        #20ns;
        phase.drop_objection(this);
    endtask: run_phase
endclass: mac_base_test

//------------------------------------------
// Top
//------------------------------------------
module top;

    reg clk;
    mac_if m_mac_if_h (clk);

    mac_unit DUT (
        .clk_i(clk),
        .rst_i(m_mac_if_h.rst_i),
        .clr_i(m_mac_if_h.clr_i),
        .en_i(m_mac_if_h.en_i),
        .a_i(m_mac_if_h.a_i),
        .b_i(m_mac_if_h.b_i),
        .acc_o(m_mac_if_h.acc_o)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5ns clk = !clk;
    end

    initial begin
        uvm_config_db#(virtual mac_if)::set(null, "*", "mac_if", m_mac_if_h);
        run_test("mac_base_test");
    end

endmodule: top