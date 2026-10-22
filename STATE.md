\# QSA-Verify STATE



\## Done

\- Tools checked: Vivado 2022.2, Python 3.13.9, Git 2.50.1

\- Folders created, git init (local, branch main)

\- Adder UVM TB passes on xsim: checks=19 errors=0



\## Files

\- .gitignore

\- STATE.md

\- tb/adder/add\_tb.sv



\## Rules learned

\- No `timescale in TB files (UVM package on xsim has none)

\- Compile: xvlog -sv -L uvm <file>.sv, then xelab -L uvm top -s <snap>, then xsim <snap> -runall



\## Next 5 steps

1\. Commit and push to GitHub (repo qsa-verify)

2\. Create tb/mac/mac\_tb.sv: signed INT8 MAC DUT + full UVM env

3\. Run it on xsim

4\. Freeze spec v1.0 (spec/)

5\. Write the vPlan (spec/)



\## Open issues

\- GitHub remote not connected yet

\- xsim 2022.2 code coverage unverified

