# QSA-Verify STATE

## Done

- Tools OK: Vivado 2022.2, Python 3.13.9, Git 2.50.1
- Adder UVM testbench passes on xsim (checks=19 errors=0)
- MAC UVM testbench passes (checks=50 errors=0); a deliberately broken MAC (+ flipped to -) fails as it should (errors=42)
- GitHub repo live and pinned: github.com/blessy-evangeline/qsa-verify
- Spec v1.0 frozen and vPlan v1.0 written (spec/)
- rtl/qsa_pe.sv and directed test tb/pe/qsa_pe_tb.sv pass (checks=22 errors=0)

## Files

.gitignore, LICENSE, README.md, STATE.md, tb/adder/add_tb.sv, tb/mac/mac_tb.sv, tb/pe/qsa_pe_tb.sv, rtl/qsa_pe.sv, spec/qsa_spec_v1.0.md, spec/qsa_vplan_v1.0.md

## Rules learned

- No `timescale in UVM testbench files (the UVM package on xsim has none)
- Directed (non-UVM) test: xvlog -sv <rtl> <tb>, then xelab <top> -s <snap>, then xsim <snap> -runall
- Commit prefixes: docs: tb: rtl: python: spec:
- Do not copy files out of the chat window: download them, or use the copy button on a code block
- Markdown needs blank lines around headings, lists and tables

## Next 5 steps

1. rtl/qsa_array.sv: NxN output-stationary array with input skew
2. Directed 2x2 tile test against hand-computed results
3. Directed 4x4 tile test
4. Measure array latency and record it in a spec revision (A10)
5. Commit and push each stage

## Open issues

- xsim 2022.2 code coverage unverified
- Array latency not yet measured
