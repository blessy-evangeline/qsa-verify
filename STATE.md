# QSA-Verify STATE

## Done

- Tools OK: Vivado 2022.2, Python 3.13.9, Git 2.50.1
- Adder UVM testbench passes on xsim (checks=19 errors=0)
- MAC UVM testbench passes (checks=50 errors=0); a deliberately broken MAC (+ flipped to -) fails as it should (errors=42)
- GitHub repo live and pinned: github.com/blessy-evangeline/qsa-verify
- Spec v1.0 frozen and vPlan v1.0 written (spec/)
- rtl/qsa_pe.sv and directed test tb/pe/qsa_pe_tb.sv pass (checks=22 errors=0)
- rtl/qsa_requant.sv and tb/requant/qsa_requant_tb.sv pass (25 directed cases: ties, saturation, bias wrap, relu order)
- UVM stage 2b (same file): register predictor in the scoreboard checks every AXI4-Lite response and read (reset values, field masks, CTRL bits, address bits [1:0] ignored, STATUS before any job, SLVERR and zero data on unmapped); register test virtual sequence (directed + 40 random accesses) runs before the jobs; a regs bug (SLVERR replaced by OKAY on unmapped writes) makes it FAIL
- UVM stage 2a (tb/uvm/qsa_uvm_s2_tb.sv): DUT = qsa_top; AXI4-Lite agent (driver, monitor, sequencer); virtual sequence programs registers, starts the job, streams the tile, polls STATUS, clears done; scoreboard builds a shadow register file from the AXI4-Lite monitor and checks every output element against the SV model; passes; a wiring bug (zero point not reaching the core) makes it FAIL
- UVM stage 1 (tb/uvm/qsa_uvm_tb.sv): stream IN agent (active), stream OUT agent (TREADY driver + monitor), scoreboard with SV reference model, base test; DUT = qsa_core with configuration through qsa_in_if; passes; a unsigned-multiplier bug in the PE (mutant M1) makes it FAIL
- RTL tidy: m_tlast_o is gated with m_tvalid_o (TLAST only while an output beat is valid); regression re-run after the change
- Regression: run_all.tcl runs all 8 tests, ALL TESTS PASSED (checks: adder 19, mac 50, pe 22, array 928, requant 25, core 83, regs 101, top 83); logs in results/logs/
- results/break_tests.md lists the 6 deliberate-bug checks (to be replaced by the 16-mutant table in Phase 6)
- Break tests done for every block: a deliberately broken copy must make its testbench FAIL (core 7/83, regs 2/101, top 9/83, requant 7/25, array 663/928, MAC 42/50)
- rtl/qsa_top.sv (regs + core) and tb/top/qsa_top_tb.sv pass: end-to-end over AXI4-Lite and AXI4-Stream with Python-derived outputs, irq, W1C, abort and recovery, illegal K
- rtl/qsa_regs.sv (AXI4-Lite registers) and tb/regs/qsa_regs_tb.sv pass: reset values, field masks, bias, start/soft_reset pulses, W1C status, irq, SLVERR on unmapped, hard reset
- Core break test (drain wait set to 0) fails with errors=7 of 83: caught only by the always-ready job; random stalls hide the bug
- rtl/qsa_core.sv (control FSM + array + requant, AXI-Stream ports) and tb/core/qsa_core_tb.sv pass: 2 Python-derived jobs, output backpressure, TLAST early/missing, illegal K, recovery after errors
- python/qsa_model.py (NumPy int64 golden model from the spec) and python/test_qsa_model.py pass (checks=30 errors=0)
- rtl/qsa_array.sv (NxN, input skew) and tb/array/qsa_array_tb.sv pass: N=2 hand-computed case plus random N=2 and N=4 (checks=928 errors=0)

## Files

.gitignore, LICENSE, run_all.tcl, results/logs/*.txt, results/screenshots/regression_summary.png, python/qsa_model.py, python/test_qsa_model.py, README.md, STATE.md, tb/adder/add_tb.sv, tb/mac/mac_tb.sv, tb/pe/qsa_pe_tb.sv, tb/array/qsa_array_tb.sv, tb/requant/qsa_requant_tb.sv, tb/core/qsa_core_tb.sv, tb/regs/qsa_regs_tb.sv, tb/top/qsa_top_tb.sv, tb/uvm/qsa_uvm_tb.sv, tb/uvm/qsa_uvm_s2_tb.sv, rtl/qsa_top.sv, rtl/qsa_core.sv, rtl/qsa_regs.sv, rtl/qsa_pe.sv, rtl/qsa_array.sv, rtl/qsa_requant.sv, spec/qsa_spec_v1.0.md, spec/qsa_vplan_v1.0.md

## Rules learned

- No `timescale in UVM testbench files (the UVM package on xsim has none)
- Directed (non-UVM) test: xvlog -sv <rtl> <tb>, then xelab <top> -s <snap>, then xsim <snap> -runall
- Commit prefixes: docs: tb: rtl: python: spec:
- Python scripts run from the repo root: python python/test_qsa_model.py
- Do not copy files out of the chat window: download them, or use the copy button on a code block
- Markdown needs blank lines around headings, lists and tables
- vivado_pid*.str files are Vivado temp files: they are in .gitignore, never commit them
- Tcl Shell: paste long commands one line at a time; never press Ctrl+C (it exits Vivado); cd into the test folder before compiling
- Keep an always-ready output test in UVM (CG_stream): random stalls can hide drain-timing bugs

## Next 5 steps

1. UVM stage 3: output backpressure and input gap knobs as config, TLAST-error jobs, illegal K, reset in every phase, back-to-back jobs, start while busy
2. UVM stage 4: covergroups (operands, config, result, stream, reg, reset) with per-group percentages in report_phase
3. UVM stage 5: SVA bind module (20+ assertions with cover properties), vector-file replay, dual-oracle cross-check against Python
4. Python regression and mutation harness (16 mutants, killed / survived table)
5. Commit and push each stage

## Open issues

- UVM stage 2 limits: no coverage yet, STATUS busy/done not predicted during jobs (only unused bits and err_len), TLAST-error and illegal-K jobs not generated, one outstanding job only
- results/screenshots/regression_summary.png still shows the 8-test run; retake it from SUMMARY.txt after uvm2 joins the regression
- Waveforms captured: top_overview.png, pe_mac_waveform.png; array and top-job zoom views optional
- xsim 2022.2 code coverage unverified
- Array latency derived on paper (last accumulate 2N-2 cycles after the last beat); the core waits a conservative 2N cycles; exact value not yet confirmed in a waveform
