// 4-bit Adder UVM Testbench (ALU-sample style)

`include "uvm_macros.svh"
import uvm_pkg::*;

//------------------------------------------
// Interface (defined first)
//------------------------------------------
interface add_if (input bit clk);
    logic [3:0] a;
    logic [3:0] b;
    logic [4:0] y;
    logic       valid;   // TB-only flag: marks a driven transaction
endinterface : add_if

//------------------------------------------
// DUT
//------------------------------------------
module add (
    input  [3:0] a,
    input  [3:0] b,
    output [4:0] y
);
    assign y = {1'b0, a} + {1'b0, b};
endmodule : add

//------------------------------------------
// Transaction
//------------------------------------------
class add_seq_item extends uvm_sequence_item;

    rand bit [3:0] a;
    rand bit [3:0] b;
    bit      [4:0] y;
    rand int       wait_cycles;

    `uvm_object_utils_begin(add_seq_item)
        `uvm_field_int(a, UVM_DEFAULT)
        `uvm_field_int(b, UVM_DEFAULT)
        `uvm_field_int(y, UVM_DEFAULT)
    `uvm_object_utils_end

    constraint delay_loops {wait_cycles inside {[0:3]};}

    function new (string name = "add_seq_item");
        super.new(name);
    endfunction: new

endclass: add_seq_item

//------------------------------------------
// Sequence
//------------------------------------------
class add_base_seq extends uvm_sequence#(add_seq_item);
    `uvm_object_utils(add_base_seq)

    rand int unsigned num_of_ops;
    constraint num_of_ops_con {num_of_ops inside {[10:20]};}

    function new(string name = "add_base_seq");
        super.new(name);
    endfunction: new

    task body();
        add_seq_item m_add_seq_item_h;
        repeat (num_of_ops) begin
            m_add_seq_item_h = add_seq_item::type_id::create("m_add_seq_item_h");
            start_item(m_add_seq_item_h);
            if (!m_add_seq_item_h.randomize()) begin
                `uvm_error("add_base_seq", "Randomize failed.")
            end
            finish_item(m_add_seq_item_h);
        end
    endtask: body
endclass: add_base_seq

//------------------------------------------
// Driver
//------------------------------------------
class add_driver extends uvm_driver#(add_seq_item);
    `uvm_component_utils(add_driver)

    virtual add_if m_add_vif_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual add_if)::get(this, "", "add_if", m_add_vif_h))
            `uvm_fatal("DRIVER", "Unable to get add_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        add_seq_item m_req_h;

        m_add_vif_h.a     = 4'b0;
        m_add_vif_h.b     = 4'b0;
        m_add_vif_h.valid = 1'b0;

        forever begin
            seq_item_port.get_next_item(m_req_h);
            @(negedge m_add_vif_h.clk);
            m_add_vif_h.a     = m_req_h.a;
            m_add_vif_h.b     = m_req_h.b;
            m_add_vif_h.valid = 1'b1;
            `uvm_info("DRIVER", $sformatf("a=%0d b=%0d", m_req_h.a, m_req_h.b), UVM_MEDIUM)
            @(negedge m_add_vif_h.clk);
            m_add_vif_h.valid = 1'b0;
            repeat (m_req_h.wait_cycles) @(negedge m_add_vif_h.clk);
            seq_item_port.item_done();
        end
    endtask: run_phase
endclass: add_driver

//------------------------------------------
// Monitor
//------------------------------------------
class add_monitor extends uvm_monitor;
    `uvm_component_utils(add_monitor)

    virtual add_if m_add_vif_h;
    uvm_analysis_port #(add_seq_item) m_analysis_port_h;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_analysis_port_h = new("m_analysis_port_h", this);
        if (!uvm_config_db#(virtual add_if)::get(this, "", "add_if", m_add_vif_h))
            `uvm_fatal("MONITOR", "Unable to get add_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        add_seq_item m_req_h;
        forever begin
            @(posedge m_add_vif_h.clk);
            if (m_add_vif_h.valid === 1'b1) begin
                // New object per sample (never reuse one handle)
                m_req_h = add_seq_item::type_id::create("m_mon_item");
                m_req_h.a = m_add_vif_h.a;
                m_req_h.b = m_add_vif_h.b;
                m_req_h.y = m_add_vif_h.y;
                `uvm_info("MONITOR", $sformatf("a=%0d b=%0d y=%0d", m_req_h.a, m_req_h.b, m_req_h.y), UVM_MEDIUM)
                m_analysis_port_h.write(m_req_h);
            end
        end
    endtask: run_phase
endclass: add_monitor

//------------------------------------------
// Agent
//------------------------------------------
class add_agent extends uvm_agent;
    `uvm_component_utils(add_agent)

    uvm_analysis_port #(add_seq_item) m_analysis_port_h;
    uvm_sequencer #(add_seq_item)     m_sequencer_h;
    add_driver                        m_driver_h;
    add_monitor                       m_monitor_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor_h       = add_monitor::type_id::create("m_monitor_h", this);
        m_analysis_port_h = new("m_analysis_port_h", this);
        m_driver_h        = add_driver::type_id::create("m_driver_h", this);
        m_sequencer_h     = uvm_sequencer#(add_seq_item)::type_id::create("m_sequencer_h", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_monitor_h.m_analysis_port_h.connect(m_analysis_port_h);
        m_driver_h.seq_item_port.connect(m_sequencer_h.seq_item_export);
    endfunction: connect_phase
endclass: add_agent

//------------------------------------------
// Scoreboard
//------------------------------------------
class add_scoreboard extends uvm_component;
    `uvm_component_utils(add_scoreboard)

    uvm_tlm_analysis_fifo #(add_seq_item) m_add_fifo_h;
    int unsigned m_checks;
    int unsigned m_errors;

    function new(string name = "add_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_add_fifo_h = new("m_add_fifo_h", this);
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        add_seq_item add_op;
        bit [4:0] expY;
        forever begin
            m_add_fifo_h.get(add_op);
            expY = {1'b0, add_op.a} + {1'b0, add_op.b};
            m_checks++;
            if (add_op.y === expY) begin
                `uvm_info("SCOREBOARD", $sformatf("CHECK_OK a=%0d b=%0d y=%0d", add_op.a, add_op.b, add_op.y), UVM_LOW)
            end else begin
                m_errors++;
                `uvm_error("SCOREBOARD", $sformatf("CHECK_FAILED a=%0d b=%0d y=%0d exp=%0d", add_op.a, add_op.b, add_op.y, expY))
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
endclass: add_scoreboard

//------------------------------------------
// Environment
//------------------------------------------
class add_env extends uvm_env;
    `uvm_component_utils(add_env)

    add_agent      m_add_agent_h;
    add_scoreboard m_scoreboard_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_add_agent_h  = add_agent::type_id::create("m_add_agent_h", this);
        m_scoreboard_h = add_scoreboard::type_id::create("m_scoreboard_h", this);
    endfunction: build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_add_agent_h.m_analysis_port_h.connect(m_scoreboard_h.m_add_fifo_h.analysis_export);
    endfunction: connect_phase
endclass: add_env

//------------------------------------------
// Test
//------------------------------------------
class add_base_test extends uvm_test;
    `uvm_component_utils(add_base_test)

    add_env m_add_env_h;

    function new(string name = "add_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_add_env_h = add_env::type_id::create("m_add_env_h", this);
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        add_base_seq m_add_seq_h;
        phase.raise_objection(this);
        m_add_seq_h = add_base_seq::type_id::create("m_add_seq_h");
        if (!m_add_seq_h.randomize()) `uvm_error("add_base_test", "Sequence randomize failed.")
        m_add_seq_h.start(m_add_env_h.m_add_agent_h.m_sequencer_h);
        #20ns;
        phase.drop_objection(this);
    endtask: run_phase
endclass: add_base_test

//------------------------------------------
// Top
//------------------------------------------
module top;

    reg clk;
    add_if m_add_if_h (clk);

    add DUT (
        .a(m_add_if_h.a),
        .b(m_add_if_h.b),
        .y(m_add_if_h.y)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5ns clk = !clk;
    end

    initial begin
        uvm_config_db#(virtual add_if)::set(null, "*", "add_if", m_add_if_h);
        run_test("add_base_test");
    end

endmodule: top