# QSA-Verify STATE

## Done

- Tools OK: Vivado 2022.2, Python 3.13.9, Git 2.50.1
- Adder UVM testbench passes on xsim (checks=19 errors=0)
- MAC UVM testbench passes (checks=50 errors=0); a deliberately broken MAC (+ flipped to -) fails as it should (errors=42)
- GitHub repo live and pinned: github.com/blessy-evangeline/qsa-verify
- Spec v1.0 frozen and vPlan v1.0 written (spec/)
- rtl/qsa_pe.sv and directed test tb/pe/qsa_pe_tb.sv pass (checks=22 errors=0)
- rtl/qsa_requant.sv and tb/requant/qsa_requant_tb.sv pass (25 directed cases: ties, saturation, bias wrap, relu order)
- rtl/qsa_array.sv (NxN, input skew) and tb/array/qsa_array_tb.sv pass: N=2 hand-computed case plus random N=2 and N=4 (checks=928 errors=0)

## Files

.gitignore, LICENSE, README.md, STATE.md, tb/adder/add_tb.sv, tb/mac/mac_tb.sv, tb/pe/qsa_pe_tb.sv, tb/array/qsa_array_tb.sv, tb/requant/qsa_requant_tb.sv, rtl/qsa_pe.sv, rtl/qsa_array.sv, rtl/qsa_requant.sv, spec/qsa_spec_v1.0.md, spec/qsa_vplan_v1.0.md

## Rules learned

- No `timescale in UVM testbench files (the UVM package on xsim has none)
- Directed (non-UVM) test: xvlog -sv <rtl> <tb>, then xelab <top> -s <snap>, then xsim <snap> -runall
- Commit prefixes: docs: tb: rtl: python: spec:
- Do not copy files out of the chat window: download them, or use the copy button on a code block
- Markdown needs blank lines around headings, lists and tables

## Next 5 steps

1. Python golden model python/qsa_model.py written from the spec (independent of the RTL)
2. rtl/qsa_ctrl.sv: control FSM (start, load K beats, compute, drain N rows, done, error)
3. Measure array latency in a waveform and record it in a spec revision (A10)
4. rtl/qsa_regs.sv: AXI4-Lite register block
5. Commit and push each stage

## Open issues

- xsim 2022.2 code coverage unverified
- Array latency derived on paper (last accumulate 2N-2 cycles after the last beat), not yet confirmed in a waveform
