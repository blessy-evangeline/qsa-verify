// QSA-Verify UVM stage 1 (same frame as the ALU sample)
//   DUT        : qsa_core (register block bypassed; configuration goes through qsa_in_if)
//   Agent A1   : stream IN  (active: sequencer, driver, monitor)
//   Agent A2   : stream OUT (monitor + TREADY driver, no sequencer)
//   Scoreboard : SystemVerilog reference model, bit-exact per output element
//   Deviation from the sample pattern: A2 is active only to drive TREADY (project plan, section 7)
`include "uvm_macros.svh"
import uvm_pkg::*;

`define QSA_N 4

//------------------------------------------
// Interfaces (defined first)
//------------------------------------------
interface qsa_in_if (input bit clk);
    logic                         rst;
    // AXI4-Stream slave side
    logic                         tvalid;
    logic                         tready;
    logic [16*`QSA_N-1:0]         tdata;
    logic                         tlast;
    // Configuration (stage 1 bypasses the AXI4-Lite register block)
    logic                         start;
    logic                         done_clr;
    logic                         err_clr;
    logic [8:0]                   k;
    logic [15:0]                  m;
    logic [4:0]                   s;
    logic signed [7:0]            zp;
    logic                         relu;
    logic [32*`QSA_N-1:0]         bias;
    // Status
    logic                         busy;
    logic                         done;
    logic                         err;
endinterface : qsa_in_if

interface qsa_out_if (input bit clk);
    logic                         tvalid;
    logic                         tready;
    logic [8*`QSA_N-1:0]          tdata;
    logic                         tlast;
endinterface : qsa_out_if

//------------------------------------------
// Environment configuration
//------------------------------------------
class qsa_env_cfg extends uvm_object;
    `uvm_object_utils(qsa_env_cfg)

    int unsigned num_jobs   = 6;
    int          ready_mode = 0;     // 0 = always ready, 1 = random stalls

    function new(string name = "qsa_env_cfg");
        super.new(name);
    endfunction: new
endclass: qsa_env_cfg

//------------------------------------------
// Job configuration (randomized per tile job)
//------------------------------------------
class qsa_job_cfg extends uvm_object;
    `uvm_object_utils(qsa_job_cfg)

    rand bit [8:0]         k;
    rand bit [15:0]        m;
    rand bit [4:0]         s;
    rand bit signed [7:0]  zp;
    rand bit               relu;
    int                    bw [`QSA_N];     // bias words, filled in post_randomize

    constraint k_c  {k  inside {[1:12]};}
    constraint m_c  {m  inside {[1:64]};}
    constraint s_c  {s  inside {[8:16]};}
    constraint zp_c {zp inside {[-20:20]};}

    function new(string name = "qsa_job_cfg");
        super.new(name);
    endfunction: new

    function void post_randomize();
        for (int i = 0; i < `QSA_N; i++) bw[i] = $urandom_range(0, 4000) - 2000;
    endfunction: post_randomize

    function bit [32*`QSA_N-1:0] bias_vec();
        bit [32*`QSA_N-1:0] v;
        v = '0;
        for (int i = 0; i < `QSA_N; i++) v[32*i +: 32] = bw[i];
        return v;
    endfunction: bias_vec
endclass: qsa_job_cfg

//------------------------------------------
// Transaction: one input stream beat
//------------------------------------------
class qsa_in_seq_item extends uvm_sequence_item;

    rand bit [8*`QSA_N-1:0] a_vec;      // A column, byte i = A[i][k]
    rand bit [8*`QSA_N-1:0] b_vec;      // B row,    byte j = B[k][j]
    rand int                gap;        // idle cycles before this beat
    bit                     tlast;
    bit                     job_start;  // first beat of a job
    qsa_job_cfg             job_cfg_h;  // valid when job_start = 1

    `uvm_object_utils_begin(qsa_in_seq_item)
        `uvm_field_int(a_vec, UVM_DEFAULT)
        `uvm_field_int(b_vec, UVM_DEFAULT)
        `uvm_field_int(gap, UVM_DEFAULT)
        `uvm_field_int(tlast, UVM_DEFAULT)
        `uvm_field_int(job_start, UVM_DEFAULT)
    `uvm_object_utils_end

    //------------------------------------------
    // Constraints and INT8 extreme bias
    //------------------------------------------
    constraint gap_c {gap dist {0 := 6, [1:3] :/ 4};}

    function new (string name = "qsa_in_seq_item");
        super.new(name);
    endfunction: new

    function bit [7:0] ext(bit [7:0] cur);
        int r;
        r = $urandom_range(0, 9);
        case (r)
            0: return 8'h80;
            1: return 8'h7F;
            2: return 8'hFF;
            3: return 8'h00;
            4: return 8'h01;
            default: return cur;
        endcase
    endfunction: ext

    function void post_randomize();
        for (int i = 0; i < `QSA_N; i++) begin
            a_vec[8*i +: 8] = ext(a_vec[8*i +: 8]);
            b_vec[8*i +: 8] = ext(b_vec[8*i +: 8]);
        end
    endfunction: post_randomize

endclass: qsa_in_seq_item

//------------------------------------------
// Observed job (what the DUT actually received)
//------------------------------------------
class qsa_job_item extends uvm_object;
    `uvm_object_utils(qsa_job_item)

    bit [8:0]              k;
    bit [15:0]             m;
    bit [4:0]              s;
    bit signed [7:0]       zp;
    bit                    relu;
    bit [32*`QSA_N-1:0]    bias;
    bit [8*`QSA_N-1:0]     a_beats [$];
    bit [8*`QSA_N-1:0]     b_beats [$];

    function new(string name = "qsa_job_item");
        super.new(name);
    endfunction: new
endclass: qsa_job_item

//------------------------------------------
// Observed output tile
//------------------------------------------
class qsa_tile_item extends uvm_object;
    `uvm_object_utils(qsa_tile_item)

    bit [8*`QSA_N-1:0]     rows [$];
    bit                    tlast_bad;

    function new(string name = "qsa_tile_item");
        super.new(name);
    endfunction: new
endclass: qsa_tile_item

//------------------------------------------
// Sequence: one tile job
//------------------------------------------
class qsa_in_base_seq extends uvm_sequence#(qsa_in_seq_item);
    `uvm_object_utils(qsa_in_base_seq)

    function new(string name = "qsa_in_base_seq");
        super.new(name);
    endfunction: new

    task body();
        qsa_job_cfg     m_job_cfg_h;
        qsa_in_seq_item m_item_h;
        m_job_cfg_h = qsa_job_cfg::type_id::create("m_job_cfg_h");
        if (!m_job_cfg_h.randomize()) begin
            `uvm_error("qsa_in_base_seq", "Job config randomize failed.")
        end
        for (int b = 0; b < m_job_cfg_h.k; b++) begin
            m_item_h = qsa_in_seq_item::type_id::create("m_item_h");
            start_item(m_item_h);
            if (!m_item_h.randomize()) begin
                `uvm_error("qsa_in_base_seq", "Randomize failed.")
            end
            m_item_h.job_start = (b == 0);
            m_item_h.tlast     = (b == m_job_cfg_h.k - 1);
            m_item_h.job_cfg_h = m_job_cfg_h;
            finish_item(m_item_h);
        end
    endtask: body
endclass: qsa_in_base_seq

//------------------------------------------
// Driver (stream IN, plus job configuration)
//------------------------------------------
class qsa_in_driver extends uvm_driver#(qsa_in_seq_item);
    `uvm_component_utils(qsa_in_driver)

    virtual qsa_in_if m_vif_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual qsa_in_if)::get(this, "", "in_if", m_vif_h))
            `uvm_fatal("DRIVER", "Unable to get in_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        qsa_in_seq_item m_req_h;

        m_vif_h.tvalid   = 1'b0;
        m_vif_h.tdata    = '0;
        m_vif_h.tlast    = 1'b0;
        m_vif_h.start    = 1'b0;
        m_vif_h.done_clr = 1'b0;
        m_vif_h.err_clr  = 1'b0;

        wait (m_vif_h.rst === 1'b0);
        @(negedge m_vif_h.clk);

        forever begin
            seq_item_port.get_next_item(m_req_h);

            if (m_req_h.job_start) begin
                // Wait for the previous job to finish, then program and start
                while (m_vif_h.busy === 1'b1) @(negedge m_vif_h.clk);
                m_vif_h.k     = m_req_h.job_cfg_h.k;
                m_vif_h.m     = m_req_h.job_cfg_h.m;
                m_vif_h.s     = m_req_h.job_cfg_h.s;
                m_vif_h.zp    = m_req_h.job_cfg_h.zp;
                m_vif_h.relu  = m_req_h.job_cfg_h.relu;
                m_vif_h.bias  = m_req_h.job_cfg_h.bias_vec();
                m_vif_h.start = 1'b1;
                @(negedge m_vif_h.clk);
                m_vif_h.start = 1'b0;
            end

            if (m_req_h.gap > 0) begin
                m_vif_h.tvalid = 1'b0;
                repeat (m_req_h.gap) @(negedge m_vif_h.clk);
            end

            // Drive the beat and hold it until the DUT accepts it
            m_vif_h.tvalid = 1'b1;
            m_vif_h.tdata  = {m_req_h.b_vec, m_req_h.a_vec};
            m_vif_h.tlast  = m_req_h.tlast;
            `uvm_info("DRIVER", $sformatf("beat a=%h b=%h tlast=%0b", m_req_h.a_vec, m_req_h.b_vec, m_req_h.tlast), UVM_DEBUG)
            do @(posedge m_vif_h.clk); while (m_vif_h.tready !== 1'b1);
            @(negedge m_vif_h.clk);
            if (m_req_h.tlast) begin
                m_vif_h.tvalid = 1'b0;
                m_vif_h.tlast  = 1'b0;
            end

            seq_item_port.item_done();
        end // forever
    endtask: run_phase
endclass: qsa_in_driver

//------------------------------------------
// Monitor (stream IN): rebuilds one job per start
//------------------------------------------
class qsa_in_monitor extends uvm_monitor;
    `uvm_component_utils(qsa_in_monitor)

    virtual qsa_in_if m_vif_h;
    uvm_analysis_port #(qsa_job_item) m_analysis_port_h;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_analysis_port_h = new("m_analysis_port_h", this);
        if (!uvm_config_db#(virtual qsa_in_if)::get(this, "", "in_if", m_vif_h))
            `uvm_fatal("MONITOR", "Unable to get in_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        qsa_job_item m_job_h;
        m_job_h = null;
        wait (m_vif_h.rst === 1'b0);
        forever begin
            @(posedge m_vif_h.clk);
            if (m_vif_h.start === 1'b1) begin
                m_job_h = qsa_job_item::type_id::create("m_job_h");
                m_job_h.k    = m_vif_h.k;
                m_job_h.m    = m_vif_h.m;
                m_job_h.s    = m_vif_h.s;
                m_job_h.zp   = m_vif_h.zp;
                m_job_h.relu = m_vif_h.relu;
                m_job_h.bias = m_vif_h.bias;
            end
            if (m_job_h != null && m_vif_h.tvalid === 1'b1 && m_vif_h.tready === 1'b1) begin
                m_job_h.a_beats.push_back(m_vif_h.tdata[8*`QSA_N-1:0]);
                m_job_h.b_beats.push_back(m_vif_h.tdata[16*`QSA_N-1:8*`QSA_N]);
                if (m_vif_h.tlast === 1'b1) begin
                    `uvm_info("MONITOR", $sformatf("job observed: K=%0d M=%0d S=%0d zp=%0d relu=%0b", m_job_h.k, m_job_h.m, m_job_h.s, m_job_h.zp, m_job_h.relu), UVM_MEDIUM)
                    m_analysis_port_h.write(m_job_h);
                    m_job_h = null;
                end
            end
        end // forever
    endtask: run_phase
endclass: qsa_in_monitor

//------------------------------------------
// Agent A1: stream IN (active)
//------------------------------------------
class qsa_in_agent extends uvm_agent;
    `uvm_component_utils(qsa_in_agent)

    uvm_analysis_port #(qsa_job_item) m_analysis_port_h;
    uvm_sequencer #(qsa_in_seq_item)  m_sequencer_h;
    qsa_in_driver                     m_driver_h;
    qsa_in_monitor                    m_monitor_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor_h       = qsa_in_monitor::type_id::create("m_monitor_h", this);
        m_analysis_port_h = new("m_analysis_port_h", this);
        m_driver_h        = qsa_in_driver::type_id::create("m_driver_h", this);
        m_sequencer_h     = uvm_sequencer#(qsa_in_seq_item)::type_id::create("m_sequencer_h", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_monitor_h.m_analysis_port_h.connect(m_analysis_port_h);
        m_driver_h.seq_item_port.connect(m_sequencer_h.seq_item_export);
    endfunction: connect_phase
endclass: qsa_in_agent

//------------------------------------------
// Driver (stream OUT): drives TREADY only
//------------------------------------------
class qsa_out_driver extends uvm_component;
    `uvm_component_utils(qsa_out_driver)

    virtual qsa_out_if m_vif_h;
    qsa_env_cfg        m_cfg_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual qsa_out_if)::get(this, "", "out_if", m_vif_h))
            `uvm_fatal("OUT_DRIVER", "Unable to get out_if from uvm_config_db")
        if (!uvm_config_db#(qsa_env_cfg)::get(this, "", "qsa_env_cfg", m_cfg_h))
            `uvm_fatal("OUT_DRIVER", "Unable to get qsa_env_cfg from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        m_vif_h.tready = 1'b1;
        forever begin
            @(negedge m_vif_h.clk);
            case (m_cfg_h.ready_mode)
                0:       m_vif_h.tready = 1'b1;
                default: m_vif_h.tready = ($urandom_range(0, 2) != 0);
            endcase
        end
    endtask: run_phase
endclass: qsa_out_driver

//------------------------------------------
// Monitor (stream OUT): rebuilds one tile per TLAST
//------------------------------------------
class qsa_out_monitor extends uvm_monitor;
    `uvm_component_utils(qsa_out_monitor)

    virtual qsa_out_if m_vif_h;
    uvm_analysis_port #(qsa_tile_item) m_analysis_port_h;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_analysis_port_h = new("m_analysis_port_h", this);
        if (!uvm_config_db#(virtual qsa_out_if)::get(this, "", "out_if", m_vif_h))
            `uvm_fatal("OUT_MONITOR", "Unable to get out_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        qsa_tile_item m_tile_h;
        m_tile_h = null;
        forever begin
            @(posedge m_vif_h.clk);
            if (m_vif_h.tvalid === 1'b1 && m_vif_h.tready === 1'b1) begin
                if (m_tile_h == null) m_tile_h = qsa_tile_item::type_id::create("m_tile_h");
                m_tile_h.rows.push_back(m_vif_h.tdata);
                if (m_vif_h.tlast === 1'b1) begin
                    if (m_tile_h.rows.size() != `QSA_N) m_tile_h.tlast_bad = 1'b1;
                    m_analysis_port_h.write(m_tile_h);
                    m_tile_h = null;
                end else if (m_tile_h.rows.size() >= `QSA_N) begin
                    m_tile_h.tlast_bad = 1'b1;     // N rows seen without TLAST
                    m_analysis_port_h.write(m_tile_h);
                    m_tile_h = null;
                end
            end
        end // forever
    endtask: run_phase
endclass: qsa_out_monitor

//------------------------------------------
// Agent A2: stream OUT
//------------------------------------------
class qsa_out_agent extends uvm_agent;
    `uvm_component_utils(qsa_out_agent)

    uvm_analysis_port #(qsa_tile_item) m_analysis_port_h;
    qsa_out_driver                     m_driver_h;
    qsa_out_monitor                    m_monitor_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor_h       = qsa_out_monitor::type_id::create("m_monitor_h", this);
        m_analysis_port_h = new("m_analysis_port_h", this);
        m_driver_h        = qsa_out_driver::type_id::create("m_driver_h", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_monitor_h.m_analysis_port_h.connect(m_analysis_port_h);
    endfunction: connect_phase
endclass: qsa_out_agent

//------------------------------------------
// Scoreboard: SV reference model (spec v1.0, Sections 2 and 3)
//------------------------------------------
class qsa_scoreboard extends uvm_component;
    `uvm_component_utils(qsa_scoreboard)

    uvm_tlm_analysis_fifo #(qsa_job_item)  m_in_fifo_h;
    uvm_tlm_analysis_fifo #(qsa_tile_item) m_out_fifo_h;

    int unsigned m_jobs_checked;
    int unsigned m_checks;
    int unsigned m_errors;

    function new(string name = "qsa_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_in_fifo_h  = new("m_in_fifo_h", this);
        m_out_fifo_h = new("m_out_fifo_h", this);
    endfunction: build_phase

    // One output element: bias, multiply, round half up, shift, zero point, clamp, relu
    function bit signed [7:0] requant(longint acc, longint bias, longint m, int unsigned s, longint zp, bit relu);
        longint sum, t, r, v;
        sum = acc + bias;
        t   = sum * m;
        if (s == 0) r = t;
        else        r = (t + (longint'(1) << (s - 1))) >>> s;
        v = r + zp;
        if (v > 127)       v = 127;
        else if (v < -128) v = -128;
        if (relu && v < 0) v = 0;
        return v[7:0];
    endfunction: requant

    task run_phase(uvm_phase phase);
        qsa_job_item  job_h;
        qsa_tile_item tile_h;
        longint       acc;
        longint       a_v, b_v;
        bit signed [7:0] exp_y;
        bit signed [7:0] got_y;

        forever begin
            m_in_fifo_h.get(job_h);
            m_out_fifo_h.get(tile_h);
            m_jobs_checked++;

            if (tile_h.tlast_bad || tile_h.rows.size() != `QSA_N) begin
                m_errors++;
                `uvm_error("SCOREBOARD", $sformatf("bad output tile: rows=%0d tlast_bad=%0b", tile_h.rows.size(), tile_h.tlast_bad))
                continue;
            end

            for (int i = 0; i < `QSA_N; i++) begin
                for (int j = 0; j < `QSA_N; j++) begin
                    acc = 0;
                    for (int k = 0; k < job_h.a_beats.size(); k++) begin
                        a_v = $signed(job_h.a_beats[k][8*i +: 8]);
                        b_v = $signed(job_h.b_beats[k][8*j +: 8]);
                        acc = acc + a_v * b_v;
                    end
                    exp_y = requant(acc, $signed(job_h.bias[32*j +: 32]), job_h.m, job_h.s, job_h.zp, job_h.relu);
                    got_y = tile_h.rows[i][8*j +: 8];
                    m_checks++;
                    if (got_y !== exp_y) begin
                        m_errors++;
                        `uvm_error("SCOREBOARD", $sformatf("CHECK_FAILED job=%0d C[%0d][%0d] got=%0d exp=%0d (K=%0d M=%0d S=%0d zp=%0d relu=%0b)",
                                   m_jobs_checked, i, j, got_y, exp_y, job_h.k, job_h.m, job_h.s, job_h.zp, job_h.relu))
                    end
                end
            end
            `uvm_info("SCOREBOARD", $sformatf("job %0d checked (K=%0d)", m_jobs_checked, job_h.a_beats.size()), UVM_LOW)
        end // forever
    endtask: run_phase

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int unsigned      n_err;
        super.report_phase(phase);
        svr   = uvm_report_server::get_server();
        n_err = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);
        if (n_err == 0 && m_errors == 0 && m_checks > 0)
            `uvm_info("SCOREBOARD", $sformatf("*** QSA UVM TEST PASSED *** checks=%0d errors=%0d (jobs=%0d)", m_checks, m_errors, m_jobs_checked), UVM_NONE)
        else
            `uvm_info("SCOREBOARD", $sformatf("*** QSA UVM TEST FAILED *** checks=%0d errors=%0d (jobs=%0d, uvm_errors=%0d)", m_checks, m_errors, m_jobs_checked, n_err), UVM_NONE)
    endfunction: report_phase
endclass: qsa_scoreboard

//------------------------------------------
// Environment
//------------------------------------------
class qsa_env extends uvm_env;
    `uvm_component_utils(qsa_env)

    qsa_in_agent    m_in_agent_h;
    qsa_out_agent   m_out_agent_h;
    qsa_scoreboard  m_scoreboard_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_in_agent_h   = qsa_in_agent::type_id::create("m_in_agent_h", this);
        m_out_agent_h  = qsa_out_agent::type_id::create("m_out_agent_h", this);
        m_scoreboard_h = qsa_scoreboard::type_id::create("m_scoreboard_h", this);
    endfunction: build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_in_agent_h.m_analysis_port_h.connect(m_scoreboard_h.m_in_fifo_h.analysis_export);
        m_out_agent_h.m_analysis_port_h.connect(m_scoreboard_h.m_out_fifo_h.analysis_export);
    endfunction: connect_phase
endclass: qsa_env

//------------------------------------------
// Test: sanity (always-ready output for the first half, random stalls for the second half)
//------------------------------------------
class qsa_base_test extends uvm_test;
    `uvm_component_utils(qsa_base_test)

    qsa_env      m_qsa_env_h;
    qsa_env_cfg  m_cfg_h;

    function new(string name = "qsa_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_cfg_h = qsa_env_cfg::type_id::create("m_cfg_h");
        uvm_config_db#(qsa_env_cfg)::set(this, "*", "qsa_env_cfg", m_cfg_h);
        m_qsa_env_h = qsa_env::type_id::create("m_qsa_env_h", this);
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        qsa_in_base_seq m_seq_h;

        phase.raise_objection(this);

        for (int j = 0; j < m_cfg_h.num_jobs; j++) begin
            if (j == m_cfg_h.num_jobs / 2) m_cfg_h.ready_mode = 1;
            m_seq_h = qsa_in_base_seq::type_id::create("m_seq_h");
            m_seq_h.start(m_qsa_env_h.m_in_agent_h.m_sequencer_h);
        end

        // Wait until every job has been checked, with a watchdog
        fork
            begin
                wait (m_qsa_env_h.m_scoreboard_h.m_jobs_checked >= m_cfg_h.num_jobs);
            end
            begin
                #500000ns;
                `uvm_error("qsa_base_test", "Timeout waiting for the scoreboard")
            end
        join_any
        disable fork;
        #50ns;

        phase.drop_objection(this);
    endtask: run_phase
endclass: qsa_base_test

//------------------------------------------
// Top
//------------------------------------------
module top;

    reg clk;
    qsa_in_if  m_in_if_h  (clk);
    qsa_out_if m_out_if_h (clk);

    qsa_core #(.N(`QSA_N)) DUT (
        .clk_i      (clk),
        .rst_i      (m_in_if_h.rst),
        .soft_rst_i (1'b0),
        .start_i    (m_in_if_h.start),
        .done_clr_i (m_in_if_h.done_clr),
        .err_clr_i  (m_in_if_h.err_clr),
        .k_i        (m_in_if_h.k),
        .m_i        (m_in_if_h.m),
        .s_i        (m_in_if_h.s),
        .zp_i       (m_in_if_h.zp),
        .relu_i     (m_in_if_h.relu),
        .bias_i     (m_in_if_h.bias),
        .s_tvalid_i (m_in_if_h.tvalid),
        .s_tready_o (m_in_if_h.tready),
        .s_tdata_i  (m_in_if_h.tdata),
        .s_tlast_i  (m_in_if_h.tlast),
        .m_tvalid_o (m_out_if_h.tvalid),
        .m_tready_i (m_out_if_h.tready),
        .m_tdata_o  (m_out_if_h.tdata),
        .m_tlast_o  (m_out_if_h.tlast),
        .busy_o     (m_in_if_h.busy),
        .done_o     (m_in_if_h.done),
        .err_len_o  (m_in_if_h.err)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5ns clk = !clk;
    end

    // Reset: held for 4 clocks
    initial begin
        m_in_if_h.rst      = 1'b1;
        m_in_if_h.tvalid   = 1'b0;
        m_in_if_h.start    = 1'b0;
        m_in_if_h.done_clr = 1'b0;
        m_in_if_h.err_clr  = 1'b0;
        m_out_if_h.tready  = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        m_in_if_h.rst = 1'b0;
    end

    // Set the interfaces to be used by the UVM testbench
    initial begin
        uvm_config_db#(virtual qsa_in_if)::set(null, "*", "in_if", m_in_if_h);
        uvm_config_db#(virtual qsa_out_if)::set(null, "*", "out_if", m_out_if_h);
        run_test("qsa_base_test");
    end

endmodule: top
