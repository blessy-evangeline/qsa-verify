# QSA-Verify STATE

## Done

- Tools OK: Vivado 2022.2, Python 3.13.9, Git 2.50.1
- Adder UVM testbench passes on xsim (checks=19 errors=0)
- MAC UVM testbench passes (checks=50 errors=0); a deliberately broken MAC (+ flipped to -) fails as it should (errors=42)
- GitHub repo live and pinned: github.com/blessy-evangeline/qsa-verify
- Spec v1.0 frozen and vPlan v1.0 written (spec/)
- rtl/qsa_pe.sv and directed test tb/pe/qsa_pe_tb.sv pass (checks=22 errors=0)
- rtl/qsa_requant.sv and tb/requant/qsa_requant_tb.sv pass (25 directed cases: ties, saturation, bias wrap, relu order)
- rtl/qsa_regs.sv (AXI4-Lite registers) and tb/regs/qsa_regs_tb.sv pass: reset values, field masks, bias, start/soft_reset pulses, W1C status, irq, SLVERR on unmapped, hard reset
- Core break test (drain wait set to 0) fails with errors=7 of 83: caught only by the always-ready job; random stalls hide the bug
- rtl/qsa_core.sv (control FSM + array + requant, AXI-Stream ports) and tb/core/qsa_core_tb.sv pass: 2 Python-derived jobs, output backpressure, TLAST early/missing, illegal K, recovery after errors
- python/qsa_model.py (NumPy int64 golden model from the spec) and python/test_qsa_model.py pass (checks=30 errors=0)
- rtl/qsa_array.sv (NxN, input skew) and tb/array/qsa_array_tb.sv pass: N=2 hand-computed case plus random N=2 and N=4 (checks=928 errors=0)

## Files

.gitignore, LICENSE, python/qsa_model.py, python/test_qsa_model.py, README.md, STATE.md, tb/adder/add_tb.sv, tb/mac/mac_tb.sv, tb/pe/qsa_pe_tb.sv, tb/array/qsa_array_tb.sv, tb/requant/qsa_requant_tb.sv, tb/core/qsa_core_tb.sv, tb/regs/qsa_regs_tb.sv, rtl/qsa_core.sv, rtl/qsa_regs.sv, rtl/qsa_pe.sv, rtl/qsa_array.sv, rtl/qsa_requant.sv, spec/qsa_spec_v1.0.md, spec/qsa_vplan_v1.0.md

## Rules learned

- No `timescale in UVM testbench files (the UVM package on xsim has none)
- Directed (non-UVM) test: xvlog -sv <rtl> <tb>, then xelab <top> -s <snap>, then xsim <snap> -runall
- Commit prefixes: docs: tb: rtl: python: spec:
- Python scripts run from the repo root: python python/test_qsa_model.py
- Do not copy files out of the chat window: download them, or use the copy button on a code block
- Markdown needs blank lines around headings, lists and tables
- Tcl Shell: paste long commands one line at a time; never press Ctrl+C (it exits Vivado); cd into the test folder before compiling
- Keep an always-ready output test in UVM (CG_stream): random stalls can hide drain-timing bugs

## Next 5 steps

1. rtl/qsa_top.sv: regs + core with spec ports (AXI4-Lite, two AXI4-Stream, irq)
2. End-to-end directed test: program registers over AXI4-Lite, stream one job, read back, compare with Python values
3. Start UVM stage 1: stream IN/OUT agents + scoreboard + sanity test
4. Measure array latency in a waveform and record it in a spec revision (A10)
5. Commit and push each stage

## Open issues

- xsim 2022.2 code coverage unverified
- Array latency derived on paper (last accumulate 2N-2 cycles after the last beat); the core waits a conservative 2N cycles; exact value not yet confirmed in a waveform
