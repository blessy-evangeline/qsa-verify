\# QSA-Verify



Coverage-driven \*\*UVM 1.2\*\* verification of a quantized \*\*INT8 systolic-array\*\* inference accelerator.



> \*\*Status: in progress.\*\* The RTL is my own simplified educational design. All figures below are measured results only; anything not yet measured says "pending".



\## What this project is

AI accelerators fail in numerics (signed INT8 extremes, rounding, saturation) and in stream handling (backpressure, reset mid-operation), which protocol-only testbenches never examine. This project builds a small INT8 MAC array (AXI4-Lite control, AXI4-Stream data) and a UVM environment around it that checks both.



\## Planned verification features

\- Numerics-aware functional coverage (operand extremes, rounding ties, saturation, K boundaries)

\- Dual-oracle checking: SystemVerilog reference model cross-checked against an independent NumPy model

\- 20+ SVA assertions with cover properties

\- Mutation testing: 16 injected RTL bugs, with the testbench kill rate measured

\- A quantized digit classifier run bit-exactly through the RTL

\- Vivado synthesis numbers (LUT / FF / DSP / Fmax)



\## Progress

| Phase | Status |

|---|---|

| 0. Environment and warm-up (adder UVM TB on xsim) | Done |

| 1. Spec v1.0 and verification plan | Pending |

| 2. RTL (MAC, then systolic array) | Pending |

| 3. Python golden model and vectors | Pending |

| 4. UVM environment | Pending |

| 5. Coverage closure | Pending |

| 6. Mutation testing | Pending |

| 7. Real-model demo | Pending |



\## Results

| Metric | Measured |

|---|---|

| Functional coverage | pending |

| Scoreboard mismatches | pending |

| Mutation score | pending |

| Real-model logit mismatches | pending |



\## Repository layout

```

spec/     specification and verification plan

rtl/      DUT (written by the author)

tb/       UVM testbenches

python/   golden model, vector generator, regression and mutation scripts

vectors/  generated stimulus and expected outputs

results/  coverage reports, logs, plots

```



\## Toolchain

AMD Vivado 2022.2 simulator (xvlog, xelab, xsim), UVM 1.2, Python 3, Git on Windows 11.



\## Run the warm-up example

```

cd tb/adder

xvlog -sv -L uvm add\_tb.sv

xelab -L uvm top -s add\_snap

xsim add\_snap -runall

```

Expected: `\*\*\* TEST PASSED \*\*\* checks=N errors=0`



\## Author

Blessy Evangeline S, B.Tech ECE (VLSI, AI/ML hardware).



\## License

MIT

