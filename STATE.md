# QSA-Verify STATE

## Done

- Tools OK: Vivado 2022.2, Python 3.13.9, Git 2.50.1
- Adder UVM testbench passes on xsim (checks=19 errors=0)
- MAC UVM testbench passes (checks=50 errors=0); a deliberately broken MAC (+ flipped to -) fails as it should (errors=42)
- GitHub repo live and pinned: github.com/blessy-evangeline/qsa-verify
- Spec v1.0 frozen and vPlan v1.0 written (spec/)
- rtl/qsa_pe.sv and directed test tb/pe/qsa_pe_tb.sv pass (checks=22 errors=0)
- rtl/qsa_requant.sv and tb/requant/qsa_requant_tb.sv pass (25 directed cases: ties, saturation, bias wrap, relu order)
- Regression: run_all.tcl runs all 8 tests, ALL TESTS PASSED (checks: adder 19, mac 50, pe 22, array 928, requant 25, core 83, regs 101, top 83); logs in results/logs/
- Break tests done for every block: a deliberately broken copy must make its testbench FAIL (core 7/83, regs 2/101, top 9/83, requant 7/25, array 663/928, MAC 42/50)
- rtl/qsa_top.sv (regs + core) and tb/top/qsa_top_tb.sv pass: end-to-end over AXI4-Lite and AXI4-Stream with Python-derived outputs, irq, W1C, abort and recovery, illegal K
- rtl/qsa_regs.sv (AXI4-Lite registers) and tb/regs/qsa_regs_tb.sv pass: reset values, field masks, bias, start/soft_reset pulses, W1C status, irq, SLVERR on unmapped, hard reset
- Core break test (drain wait set to 0) fails with errors=7 of 83: caught only by the always-ready job; random stalls hide the bug
- rtl/qsa_core.sv (control FSM + array + requant, AXI-Stream ports) and tb/core/qsa_core_tb.sv pass: 2 Python-derived jobs, output backpressure, TLAST early/missing, illegal K, recovery after errors
- python/qsa_model.py (NumPy int64 golden model from the spec) and python/test_qsa_model.py pass (checks=30 errors=0)
- rtl/qsa_array.sv (NxN, input skew) and tb/array/qsa_array_tb.sv pass: N=2 hand-computed case plus random N=2 and N=4 (checks=928 errors=0)

## Files

.gitignore, LICENSE, run_all.tcl, results/logs/*.txt, results/screenshots/regression_summary.png, python/qsa_model.py, python/test_qsa_model.py, README.md, STATE.md, tb/adder/add_tb.sv, tb/mac/mac_tb.sv, tb/pe/qsa_pe_tb.sv, tb/array/qsa_array_tb.sv, tb/requant/qsa_requant_tb.sv, tb/core/qsa_core_tb.sv, tb/regs/qsa_regs_tb.sv, tb/top/qsa_top_tb.sv, rtl/qsa_top.sv, rtl/qsa_core.sv, rtl/qsa_regs.sv, rtl/qsa_pe.sv, rtl/qsa_array.sv, rtl/qsa_requant.sv, spec/qsa_spec_v1.0.md, spec/qsa_vplan_v1.0.md

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

1. UVM stage 1 in tb/uvm/: interfaces, stream IN and OUT agents, scoreboard with SV reference model, sanity test
2. Measure array latency in a waveform and record it in a spec revision (A10)
3. UVM stage 2: AXI4-Lite agent and register tests
4. UVM stage 3: backpressure and gap knobs, error, reset and back-to-back tests
5. Commit and push each stage

## Open issues

- Waveform screenshots (results/waveforms/) not captured yet; optional, do after UVM stage 1
- m_tlast stays high after a job (legal, but gate it with m_tvalid before the UVM monitor and SVA work)
- xsim 2022.2 code coverage unverified
- Array latency derived on paper (last accumulate 2N-2 cycles after the last beat); the core waits a conservative 2N cycles; exact value not yet confirmed in a waveform
