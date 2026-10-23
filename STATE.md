\# QSA-Verify STATE



\## Done

\- Tools OK: Vivado 2022.2, Python 3.13.9, Git 2.50.1

\- Adder UVM TB passes on xsim (checks=19 errors=0)

\- GitHub repo live: github.com/blessy-evangeline/qsa-verify (README, MIT, pinned)

\- MAC UVM TB passes on xsim (checks=50 errors=0): tb/mac/mac\_tb.sv

\- Sanity: deliberately broken MAC must FAIL (see next steps)



\## Files

.gitignore, LICENSE, README.md, STATE.md, tb/adder/add\_tb.sv, tb/mac/mac\_tb.sv



\## Rules learned

\- No `timescale in TB files (UVM pkg on xsim has none)

\- Commit prefixes: docs: tb: rtl: python: spec:

\- Paste block, press Enter once, wait for Vivado% prompt

\- Pasted text can come out with doubled blank lines: check after saving



\## Next 5 steps

1\. Freeze spec v1.0 in spec/ (PDF section 6)

2\. Write the vPlan in spec/ (PDF section 8)

3\. Start RTL: PE + array in rtl/

4\. Directed tests for the array

5\. Commit and push after each stage



\## Open issues

\- xsim 2022.2 code coverage unverified

