// QSA-Verify UVM stage 2a (same frame as the ALU sample)
//   DUT        : qsa_top (AXI4-Lite registers + control core)
//   Agent A1   : stream IN   (active: sequencer, driver, monitor)
//   Agent A2   : stream OUT  (monitor + TREADY driver)
//   Agent A3   : AXI4-Lite   (active: sequencer, driver, monitor)
//   Virtual sequence: program registers, stream the tile, poll STATUS, clear done
//   Scoreboard : shadow register model built from the AXI4-Lite monitor, plus the
//                SystemVerilog reference model of stage 1
`include "uvm_macros.svh"
import uvm_pkg::*;

`define QSA_N 4

//------------------------------------------
// Interfaces (defined first)
//------------------------------------------
interface qsa_axil_if (input bit clk, input bit aresetn);
    logic [7:0]   awaddr;
    logic         awvalid;
    logic         awready;
    logic [31:0]  wdata;
    logic [3:0]   wstrb;
    logic         wvalid;
    logic         wready;
    logic [1:0]   bresp;
    logic         bvalid;
    logic         bready;
    logic [7:0]   araddr;
    logic         arvalid;
    logic         arready;
    logic [31:0]  rdata;
    logic [1:0]   rresp;
    logic         rvalid;
    logic         rready;
    logic         irq;
endinterface : qsa_axil_if

interface qsa_in_if (input bit clk, input bit aresetn);
    logic                         tvalid;
    logic                         tready;
    logic [16*`QSA_N-1:0]         tdata;
    logic                         tlast;
endinterface : qsa_in_if

interface qsa_out_if (input bit clk, input bit aresetn);
    logic                         tvalid;
    logic                         tready;
    logic [8*`QSA_N-1:0]          tdata;
    logic                         tlast;
endinterface : qsa_out_if

//------------------------------------------
// Job configuration snapshot (taken by the scoreboard at the start write)
//------------------------------------------
class qsa_cfg_snap extends uvm_object;
    `uvm_object_utils(qsa_cfg_snap)

    bit [8:0]          k;
    bit [15:0]         m;
    bit [4:0]          s;
    bit signed [7:0]   zp;
    bit                relu;
    bit [31:0]         bias [`QSA_N];

    function new(string name = "qsa_cfg_snap");
        super.new(name);
    endfunction: new
endclass: qsa_cfg_snap

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
endclass: qsa_job_cfg

//------------------------------------------
// Transaction: one AXI4-Lite access
//------------------------------------------
class qsa_axil_seq_item extends uvm_sequence_item;

    bit          is_write;
    bit [7:0]    addr;
    bit [31:0]   data;       // write data
    rand int     idle;       // idle cycles before the access
    bit [1:0]    resp;       // returned by the driver / rebuilt by the monitor
    bit [31:0]   rdata;      // read data

    `uvm_object_utils_begin(qsa_axil_seq_item)
        `uvm_field_int(is_write, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT)
        `uvm_field_int(data, UVM_DEFAULT)
        `uvm_field_int(resp, UVM_DEFAULT)
        `uvm_field_int(rdata, UVM_DEFAULT)
    `uvm_object_utils_end

    constraint idle_c {idle inside {[0:2]};}

    function new (string name = "qsa_axil_seq_item");
        super.new(name);
    endfunction: new
endclass: qsa_axil_seq_item

//------------------------------------------
// Transaction: one input stream beat
//------------------------------------------
class qsa_in_seq_item extends uvm_sequence_item;

    rand bit [8*`QSA_N-1:0] a_vec;      // A column, byte i = A[i][k]
    rand bit [8*`QSA_N-1:0] b_vec;      // B row,    byte j = B[k][j]
    rand int                gap;        // idle cycles before this beat
    bit                     tlast;

    `uvm_object_utils_begin(qsa_in_seq_item)
        `uvm_field_int(a_vec, UVM_DEFAULT)
        `uvm_field_int(b_vec, UVM_DEFAULT)
        `uvm_field_int(gap, UVM_DEFAULT)
        `uvm_field_int(tlast, UVM_DEFAULT)
    `uvm_object_utils_end

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
// Observed input beats of one job
//------------------------------------------
class qsa_beats_item extends uvm_object;
    `uvm_object_utils(qsa_beats_item)

    bit [8*`QSA_N-1:0]     a_beats [$];
    bit [8*`QSA_N-1:0]     b_beats [$];

    function new(string name = "qsa_beats_item");
        super.new(name);
    endfunction: new
endclass: qsa_beats_item

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
// Sequence: one AXI4-Lite access (caller sets is_write, addr, data)
//------------------------------------------
class qsa_axil_base_seq extends uvm_sequence#(qsa_axil_seq_item);
    `uvm_object_utils(qsa_axil_base_seq)

    bit          is_write;
    bit [7:0]    addr;
    bit [31:0]   data;
    bit [1:0]    resp_o;
    bit [31:0]   rdata_o;

    function new(string name = "qsa_axil_base_seq");
        super.new(name);
    endfunction: new

    task body();
        qsa_axil_seq_item m_item_h;
        m_item_h = qsa_axil_seq_item::type_id::create("m_item_h");
        start_item(m_item_h);
        if (!m_item_h.randomize()) begin
            `uvm_error("qsa_axil_base_seq", "Randomize failed.")
        end
        m_item_h.is_write = is_write;
        m_item_h.addr     = addr;
        m_item_h.data     = data;
        finish_item(m_item_h);
        resp_o  = m_item_h.resp;
        rdata_o = m_item_h.rdata;
    endtask: body
endclass: qsa_axil_base_seq

//------------------------------------------
// Sequence: K input stream beats (one job)
//------------------------------------------
class qsa_in_base_seq extends uvm_sequence#(qsa_in_seq_item);
    `uvm_object_utils(qsa_in_base_seq)

    int unsigned k_beats = 1;

    function new(string name = "qsa_in_base_seq");
        super.new(name);
    endfunction: new

    task body();
        qsa_in_seq_item m_item_h;
        for (int b = 0; b < k_beats; b++) begin
            m_item_h = qsa_in_seq_item::type_id::create("m_item_h");
            start_item(m_item_h);
            if (!m_item_h.randomize()) begin
                `uvm_error("qsa_in_base_seq", "Randomize failed.")
            end
            m_item_h.tlast = (b == k_beats - 1);
            finish_item(m_item_h);
        end
    endtask: body
endclass: qsa_in_base_seq

//------------------------------------------
// Virtual sequence: one complete tile job, as software would do it
//   1. program K, QM, QS, ZP and the bias registers
//   2. write CTRL (start, relu) and stream the K beats
//   3. poll STATUS until done, then write 1 to clear done
//------------------------------------------
class qsa_job_vseq extends uvm_sequence;
    `uvm_object_utils(qsa_job_vseq)

    uvm_sequencer #(qsa_axil_seq_item) m_axil_sqr_h;
    uvm_sequencer #(qsa_in_seq_item)   m_in_sqr_h;

    function new(string name = "qsa_job_vseq");
        super.new(name);
    endfunction: new

    task wr(bit [7:0] a, bit [31:0] d);
        qsa_axil_base_seq s_h;
        s_h = qsa_axil_base_seq::type_id::create("s_h");
        s_h.is_write = 1'b1;
        s_h.addr     = a;
        s_h.data     = d;
        s_h.start(m_axil_sqr_h);
        if (s_h.resp_o != 2'b00)
            `uvm_error("qsa_job_vseq", $sformatf("write to 0x%0h returned resp=%0d", a, s_h.resp_o))
    endtask: wr

    task rd(bit [7:0] a, output bit [31:0] d);
        qsa_axil_base_seq s_h;
        s_h = qsa_axil_base_seq::type_id::create("s_h");
        s_h.is_write = 1'b0;
        s_h.addr     = a;
        s_h.data     = 32'd0;
        s_h.start(m_axil_sqr_h);
        d = s_h.rdata_o;
    endtask: rd

    task body();
        qsa_job_cfg     m_job_cfg_h;
        qsa_in_base_seq m_beats_h;
        bit [31:0]      st;
        int             polls;

        m_job_cfg_h = qsa_job_cfg::type_id::create("m_job_cfg_h");
        if (!m_job_cfg_h.randomize()) begin
            `uvm_error("qsa_job_vseq", "Job config randomize failed.")
        end

        wr(8'h08, {23'd0, m_job_cfg_h.k});
        wr(8'h0C, {16'd0, m_job_cfg_h.m});
        wr(8'h10, {27'd0, m_job_cfg_h.s});
        wr(8'h14, {24'd0, m_job_cfg_h.zp});
        for (int i = 0; i < `QSA_N; i++) wr(8'h20 + 4*i, m_job_cfg_h.bw[i]);

        fork
            begin
                m_beats_h = qsa_in_base_seq::type_id::create("m_beats_h");
                m_beats_h.k_beats = m_job_cfg_h.k;
                m_beats_h.start(m_in_sqr_h);
            end
            begin
                wr(8'h00, m_job_cfg_h.relu ? 32'h5 : 32'h1);
                polls = 0;
                st    = 32'd0;
                while (st[1] !== 1'b1 && polls < 400) begin
                    rd(8'h04, st);
                    polls++;
                end
                if (st[1] !== 1'b1)
                    `uvm_error("qsa_job_vseq", "Timeout waiting for STATUS.done")
                wr(8'h04, 32'h2);
            end
        join
    endtask: body
endclass: qsa_job_vseq

//------------------------------------------
// Driver (AXI4-Lite master)
//------------------------------------------
class qsa_axil_driver extends uvm_driver#(qsa_axil_seq_item);
    `uvm_component_utils(qsa_axil_driver)

    virtual qsa_axil_if m_vif_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual qsa_axil_if)::get(this, "", "axil_if", m_vif_h))
            `uvm_fatal("AXIL_DRIVER", "Unable to get axil_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        qsa_axil_seq_item m_req_h;

        m_vif_h.awvalid = 1'b0;
        m_vif_h.wvalid  = 1'b0;
        m_vif_h.bready  = 1'b0;
        m_vif_h.arvalid = 1'b0;
        m_vif_h.rready  = 1'b0;
        m_vif_h.wstrb   = 4'hF;

        wait (m_vif_h.aresetn === 1'b1);
        @(negedge m_vif_h.clk);

        forever begin
            seq_item_port.get_next_item(m_req_h);
            repeat (m_req_h.idle) @(negedge m_vif_h.clk);

            if (m_req_h.is_write) begin
                @(negedge m_vif_h.clk);
                m_vif_h.awaddr  = m_req_h.addr;
                m_vif_h.wdata   = m_req_h.data;
                m_vif_h.awvalid = 1'b1;
                m_vif_h.wvalid  = 1'b1;
                m_vif_h.bready  = 1'b0;
                @(negedge m_vif_h.clk);
                m_vif_h.awvalid = 1'b0;
                m_vif_h.wvalid  = 1'b0;
                if (m_vif_h.bvalid !== 1'b1)
                    `uvm_error("AXIL_DRIVER", $sformatf("no BVALID after write to 0x%0h", m_req_h.addr))
                m_req_h.resp   = m_vif_h.bresp;
                m_vif_h.bready = 1'b1;
                @(negedge m_vif_h.clk);
                m_vif_h.bready = 1'b0;
            end else begin
                @(negedge m_vif_h.clk);
                m_vif_h.araddr  = m_req_h.addr;
                m_vif_h.arvalid = 1'b1;
                m_vif_h.rready  = 1'b0;
                @(negedge m_vif_h.clk);
                m_vif_h.arvalid = 1'b0;
                if (m_vif_h.rvalid !== 1'b1)
                    `uvm_error("AXIL_DRIVER", $sformatf("no RVALID after read of 0x%0h", m_req_h.addr))
                m_req_h.rdata  = m_vif_h.rdata;
                m_req_h.resp   = m_vif_h.rresp;
                m_vif_h.rready = 1'b1;
                @(negedge m_vif_h.clk);
                m_vif_h.rready = 1'b0;
            end

            seq_item_port.item_done();
        end // forever
    endtask: run_phase
endclass: qsa_axil_driver

//------------------------------------------
// Monitor (AXI4-Lite): rebuilds one item per completed access
//------------------------------------------
class qsa_axil_monitor extends uvm_monitor;
    `uvm_component_utils(qsa_axil_monitor)

    virtual qsa_axil_if m_vif_h;
    uvm_analysis_port #(qsa_axil_seq_item) m_analysis_port_h;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_analysis_port_h = new("m_analysis_port_h", this);
        if (!uvm_config_db#(virtual qsa_axil_if)::get(this, "", "axil_if", m_vif_h))
            `uvm_fatal("AXIL_MONITOR", "Unable to get axil_if from uvm_config_db")
    endfunction: build_phase

    task run_phase(uvm_phase phase);
        qsa_axil_seq_item w_h;
        qsa_axil_seq_item r_h;
        w_h = null;
        r_h = null;
        wait (m_vif_h.aresetn === 1'b1);
        forever begin
            @(posedge m_vif_h.clk);
            if (m_vif_h.awvalid === 1'b1 && m_vif_h.awready === 1'b1 &&
                m_vif_h.wvalid  === 1'b1 && m_vif_h.wready  === 1'b1) begin
                w_h = qsa_axil_seq_item::type_id::create("w_h");
                w_h.is_write = 1'b1;
                w_h.addr     = m_vif_h.awaddr;
                w_h.data     = m_vif_h.wdata;
            end
            if (m_vif_h.arvalid === 1'b1 && m_vif_h.arready === 1'b1) begin
                r_h = qsa_axil_seq_item::type_id::create("r_h");
                r_h.is_write = 1'b0;
                r_h.addr     = m_vif_h.araddr;
            end
            if (m_vif_h.bvalid === 1'b1 && m_vif_h.bready === 1'b1 && w_h != null) begin
                w_h.resp = m_vif_h.bresp;
                `uvm_info("AXIL_MONITOR", $sformatf("write addr=0x%0h data=0x%0h resp=%0d", w_h.addr, w_h.data, w_h.resp), UVM_HIGH)
                m_analysis_port_h.write(w_h);
                w_h = null;
            end
            if (m_vif_h.rvalid === 1'b1 && m_vif_h.rready === 1'b1 && r_h != null) begin
                r_h.resp  = m_vif_h.rresp;
                r_h.rdata = m_vif_h.rdata;
                `uvm_info("AXIL_MONITOR", $sformatf("read addr=0x%0h data=0x%0h resp=%0d", r_h.addr, r_h.rdata, r_h.resp), UVM_HIGH)
                m_analysis_port_h.write(r_h);
                r_h = null;
            end
        end // forever
    endtask: run_phase
endclass: qsa_axil_monitor

//------------------------------------------
// Agent A3: AXI4-Lite (active)
//------------------------------------------
class qsa_axil_agent extends uvm_agent;
    `uvm_component_utils(qsa_axil_agent)

    uvm_analysis_port #(qsa_axil_seq_item) m_analysis_port_h;
    uvm_sequencer #(qsa_axil_seq_item)     m_sequencer_h;
    qsa_axil_driver                        m_driver_h;
    qsa_axil_monitor                       m_monitor_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_monitor_h       = qsa_axil_monitor::type_id::create("m_monitor_h", this);
        m_analysis_port_h = new("m_analysis_port_h", this);
        m_driver_h        = qsa_axil_driver::type_id::create("m_driver_h", this);
        m_sequencer_h     = uvm_sequencer#(qsa_axil_seq_item)::type_id::create("m_sequencer_h", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_monitor_h.m_analysis_port_h.connect(m_analysis_port_h);
        m_driver_h.seq_item_port.connect(m_sequencer_h.seq_item_export);
    endfunction: connect_phase
endclass: qsa_axil_agent

//------------------------------------------
// Driver (stream IN)
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

        m_vif_h.tvalid = 1'b0;
        m_vif_h.tdata  = '0;
        m_vif_h.tlast  = 1'b0;

        wait (m_vif_h.aresetn === 1'b1);
        @(negedge m_vif_h.clk);

        forever begin
            seq_item_port.get_next_item(m_req_h);

            if (m_req_h.gap > 0) begin
                m_vif_h.tvalid = 1'b0;
                repeat (m_req_h.gap) @(negedge m_vif_h.clk);
            end

            // Drive the beat and hold it until the DUT accepts it
            m_vif_h.tvalid = 1'b1;
            m_vif_h.tdata  = {m_req_h.b_vec, m_req_h.a_vec};
            m_vif_h.tlast  = m_req_h.tlast;
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
// Monitor (stream IN): rebuilds the beats of one job per TLAST
//------------------------------------------
class qsa_in_monitor extends uvm_monitor;
    `uvm_component_utils(qsa_in_monitor)

    virtual qsa_in_if m_vif_h;
    uvm_analysis_port #(qsa_beats_item) m_analysis_port_h;

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
        qsa_beats_item m_beats_h;
        m_beats_h = null;
        wait (m_vif_h.aresetn === 1'b1);
        forever begin
            @(posedge m_vif_h.clk);
            if (m_vif_h.tvalid === 1'b1 && m_vif_h.tready === 1'b1) begin
                if (m_beats_h == null) m_beats_h = qsa_beats_item::type_id::create("m_beats_h");
                m_beats_h.a_beats.push_back(m_vif_h.tdata[8*`QSA_N-1:0]);
                m_beats_h.b_beats.push_back(m_vif_h.tdata[16*`QSA_N-1:8*`QSA_N]);
                if (m_vif_h.tlast === 1'b1) begin
                    `uvm_info("MONITOR", $sformatf("job beats observed: K=%0d", m_beats_h.a_beats.size()), UVM_MEDIUM)
                    m_analysis_port_h.write(m_beats_h);
                    m_beats_h = null;
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

    uvm_analysis_port #(qsa_beats_item) m_analysis_port_h;
    uvm_sequencer #(qsa_in_seq_item)    m_sequencer_h;
    qsa_in_driver                       m_driver_h;
    qsa_in_monitor                      m_monitor_h;

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
// Scoreboard: shadow registers from the AXI4-Lite monitor + SV reference model
//------------------------------------------
class qsa_scoreboard extends uvm_component;
    `uvm_component_utils(qsa_scoreboard)

    uvm_tlm_analysis_fifo #(qsa_axil_seq_item) m_axil_fifo_h;
    uvm_tlm_analysis_fifo #(qsa_beats_item)    m_in_fifo_h;
    uvm_tlm_analysis_fifo #(qsa_tile_item)     m_out_fifo_h;

    // Shadow copy of the register file, built only from observed AXI4-Lite writes
    bit [8:0]          m_sh_k;
    bit [15:0]         m_sh_m;
    bit [4:0]          m_sh_s;
    bit signed [7:0]   m_sh_zp;
    bit                m_sh_relu;
    bit [31:0]         m_sh_bias [`QSA_N];
    qsa_cfg_snap       m_cfg_q [$];

    int unsigned m_jobs_checked;
    int unsigned m_checks;
    int unsigned m_errors;

    function new(string name = "qsa_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_axil_fifo_h = new("m_axil_fifo_h", this);
        m_in_fifo_h   = new("m_in_fifo_h", this);
        m_out_fifo_h  = new("m_out_fifo_h", this);
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

    // Update the shadow registers from one observed write; a start write takes a snapshot
    function void update_shadow(qsa_axil_seq_item t);
        qsa_cfg_snap snap;
        bit [5:0]    widx;
        widx = t.addr[7:2];
        `uvm_info("SCOREBOARD", $sformatf("shadow write addr=0x%0h data=0x%0h", t.addr, t.data), UVM_MEDIUM)
        if (widx == 6'd0) begin
            m_sh_relu = t.data[2];
            if (t.data[0] && !t.data[1]) begin
                snap = qsa_cfg_snap::type_id::create("snap");
                snap.k    = m_sh_k;
                snap.m    = m_sh_m;
                snap.s    = m_sh_s;
                snap.zp   = m_sh_zp;
                snap.relu = m_sh_relu;
                for (int i = 0; i < `QSA_N; i++) snap.bias[i] = m_sh_bias[i];
                `uvm_info("SCOREBOARD", $sformatf("start: snapshot K=%0d M=%0d S=%0d zp=%0d relu=%0b", snap.k, snap.m, snap.s, snap.zp, snap.relu), UVM_MEDIUM)
                m_cfg_q.push_back(snap);
            end
        end
        else if (widx == 6'd2) m_sh_k  = t.data[8:0];
        else if (widx == 6'd3) m_sh_m  = t.data[15:0];
        else if (widx == 6'd4) m_sh_s  = t.data[4:0];
        else if (widx == 6'd5) m_sh_zp = t.data[7:0];
        else if (widx >= 6'd8 && widx < 6'd8 + `QSA_N) m_sh_bias[widx - 6'd8] = t.data;
    endfunction: update_shadow

    task axil_thread();
        qsa_axil_seq_item t_h;
        forever begin
            m_axil_fifo_h.get(t_h);
            if (t_h.is_write && t_h.resp == 2'b00) update_shadow(t_h);
        end
    endtask: axil_thread

    task compare_thread();
        qsa_cfg_snap     cfg;
        qsa_beats_item   beats_h;
        qsa_tile_item    tile_h;
        longint          acc;
        longint          a_v, b_v;
        bit signed [7:0] exp_y;
        bit signed [7:0] got_y;

        forever begin
            wait (m_cfg_q.size() > 0);
            cfg = m_cfg_q.pop_front();
            m_in_fifo_h.get(beats_h);
            m_out_fifo_h.get(tile_h);
            m_jobs_checked++;

            if (cfg.k != beats_h.a_beats.size()) begin
                m_errors++;
                `uvm_error("SCOREBOARD", $sformatf("K register=%0d but %0d beats were streamed", cfg.k, beats_h.a_beats.size()))
            end

            if (tile_h.tlast_bad || tile_h.rows.size() != `QSA_N) begin
                m_errors++;
                `uvm_error("SCOREBOARD", $sformatf("bad output tile: rows=%0d tlast_bad=%0b", tile_h.rows.size(), tile_h.tlast_bad))
                continue;
            end

            for (int i = 0; i < `QSA_N; i++) begin
                for (int j = 0; j < `QSA_N; j++) begin
                    acc = 0;
                    for (int k = 0; k < beats_h.a_beats.size(); k++) begin
                        a_v = $signed(beats_h.a_beats[k][8*i +: 8]);
                        b_v = $signed(beats_h.b_beats[k][8*j +: 8]);
                        acc = acc + a_v * b_v;
                    end
                    exp_y = requant(acc, $signed(cfg.bias[j]), cfg.m, cfg.s, cfg.zp, cfg.relu);
                    got_y = tile_h.rows[i][8*j +: 8];
                    m_checks++;
                    if (got_y !== exp_y) begin
                        m_errors++;
                        `uvm_error("SCOREBOARD", $sformatf("CHECK_FAILED job=%0d C[%0d][%0d] got=%0d exp=%0d (K=%0d M=%0d S=%0d zp=%0d relu=%0b)",
                                   m_jobs_checked, i, j, got_y, exp_y, cfg.k, cfg.m, cfg.s, cfg.zp, cfg.relu))
                    end
                end
            end
            `uvm_info("SCOREBOARD", $sformatf("job %0d checked (K=%0d)", m_jobs_checked, beats_h.a_beats.size()), UVM_LOW)
        end // forever
    endtask: compare_thread

    task run_phase(uvm_phase phase);
        fork
            axil_thread();
            compare_thread();
        join
    endtask: run_phase

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int unsigned      n_err;
        super.report_phase(phase);
        svr   = uvm_report_server::get_server();
        n_err = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);
        if (n_err == 0 && m_errors == 0 && m_checks > 0)
            `uvm_info("SCOREBOARD", $sformatf("*** QSA UVM2 TEST PASSED *** checks=%0d errors=%0d (jobs=%0d)", m_checks, m_errors, m_jobs_checked), UVM_NONE)
        else
            `uvm_info("SCOREBOARD", $sformatf("*** QSA UVM2 TEST FAILED *** checks=%0d errors=%0d (jobs=%0d, uvm_errors=%0d)", m_checks, m_errors, m_jobs_checked, n_err), UVM_NONE)
    endfunction: report_phase
endclass: qsa_scoreboard

//------------------------------------------
// Environment
//------------------------------------------
class qsa_env extends uvm_env;
    `uvm_component_utils(qsa_env)

    qsa_axil_agent  m_axil_agent_h;
    qsa_in_agent    m_in_agent_h;
    qsa_out_agent   m_out_agent_h;
    qsa_scoreboard  m_scoreboard_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_axil_agent_h = qsa_axil_agent::type_id::create("m_axil_agent_h", this);
        m_in_agent_h   = qsa_in_agent::type_id::create("m_in_agent_h", this);
        m_out_agent_h  = qsa_out_agent::type_id::create("m_out_agent_h", this);
        m_scoreboard_h = qsa_scoreboard::type_id::create("m_scoreboard_h", this);
    endfunction: build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_axil_agent_h.m_analysis_port_h.connect(m_scoreboard_h.m_axil_fifo_h.analysis_export);
        m_in_agent_h.m_analysis_port_h.connect(m_scoreboard_h.m_in_fifo_h.analysis_export);
        m_out_agent_h.m_analysis_port_h.connect(m_scoreboard_h.m_out_fifo_h.analysis_export);
    endfunction: connect_phase
endclass: qsa_env

//------------------------------------------
// Test: register-programmed jobs (always-ready output first, random stalls second)
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
        qsa_job_vseq m_vseq_h;

        phase.raise_objection(this);

        for (int j = 0; j < m_cfg_h.num_jobs; j++) begin
            if (j == m_cfg_h.num_jobs / 2) m_cfg_h.ready_mode = 1;
            m_vseq_h = qsa_job_vseq::type_id::create("m_vseq_h");
            m_vseq_h.m_axil_sqr_h = m_qsa_env_h.m_axil_agent_h.m_sequencer_h;
            m_vseq_h.m_in_sqr_h   = m_qsa_env_h.m_in_agent_h.m_sequencer_h;
            m_vseq_h.start(null);
        end

        // Wait until every job has been checked, with a watchdog
        fork
            begin
                wait (m_qsa_env_h.m_scoreboard_h.m_jobs_checked >= m_cfg_h.num_jobs);
            end
            begin
                #1000000ns;
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
    reg aresetn;
    qsa_axil_if m_axil_if_h (clk, aresetn);
    qsa_in_if   m_in_if_h   (clk, aresetn);
    qsa_out_if  m_out_if_h  (clk, aresetn);

    qsa_top #(.N(`QSA_N)) DUT (
        .aclk           (clk),
        .aresetn        (aresetn),
        .s_axil_awaddr  (m_axil_if_h.awaddr),
        .s_axil_awvalid (m_axil_if_h.awvalid),
        .s_axil_awready (m_axil_if_h.awready),
        .s_axil_wdata   (m_axil_if_h.wdata),
        .s_axil_wstrb   (m_axil_if_h.wstrb),
        .s_axil_wvalid  (m_axil_if_h.wvalid),
        .s_axil_wready  (m_axil_if_h.wready),
        .s_axil_bresp   (m_axil_if_h.bresp),
        .s_axil_bvalid  (m_axil_if_h.bvalid),
        .s_axil_bready  (m_axil_if_h.bready),
        .s_axil_araddr  (m_axil_if_h.araddr),
        .s_axil_arvalid (m_axil_if_h.arvalid),
        .s_axil_arready (m_axil_if_h.arready),
        .s_axil_rdata   (m_axil_if_h.rdata),
        .s_axil_rresp   (m_axil_if_h.rresp),
        .s_axil_rvalid  (m_axil_if_h.rvalid),
        .s_axil_rready  (m_axil_if_h.rready),
        .s_axis_tdata   (m_in_if_h.tdata),
        .s_axis_tvalid  (m_in_if_h.tvalid),
        .s_axis_tready  (m_in_if_h.tready),
        .s_axis_tlast   (m_in_if_h.tlast),
        .m_axis_tdata   (m_out_if_h.tdata),
        .m_axis_tvalid  (m_out_if_h.tvalid),
        .m_axis_tready  (m_out_if_h.tready),
        .m_axis_tlast   (m_out_if_h.tlast),
        .irq            (m_axil_if_h.irq)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5ns clk = !clk;
    end

    // Reset: held for 4 clocks
    initial begin
        aresetn = 1'b0;
        m_axil_if_h.awvalid = 1'b0;
        m_axil_if_h.wvalid  = 1'b0;
        m_axil_if_h.bready  = 1'b0;
        m_axil_if_h.arvalid = 1'b0;
        m_axil_if_h.rready  = 1'b0;
        m_axil_if_h.wstrb   = 4'hF;
        m_in_if_h.tvalid    = 1'b0;
        m_out_if_h.tready   = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        aresetn = 1'b1;
    end

    // Set the interfaces to be used by the UVM testbench
    initial begin
        uvm_config_db#(virtual qsa_axil_if)::set(null, "*", "axil_if", m_axil_if_h);
        uvm_config_db#(virtual qsa_in_if)::set(null, "*", "in_if", m_in_if_h);
        uvm_config_db#(virtual qsa_out_if)::set(null, "*", "out_if", m_out_if_h);
        run_test("qsa_base_test");
    end

endmodule: top
