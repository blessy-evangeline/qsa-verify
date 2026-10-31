# break_regs_uvm2.tcl : register-block bug (write to an unmapped address answers OKAY instead of SLVERR).
# The UVM register test must FAIL on this broken copy. Run from the repo root:
#     cd D:/VivadoProjects/qsa_verify
#     source scripts/break_regs_uvm2.tcl
set root [pwd]
cd $root/tb/uvm
set R $root/rtl
set fi [open $R/qsa_regs.sv r]
set t [read $fi]
close $fi
set old {w_map ? 2'b00 : 2'b10}
set new {2'b00}
set t [string map [list $old $new] $t]
if {[string first {w_map ? 2'b00} $t] != -1} {
    puts "REPLACE FAILED: the text was not found in rtl/qsa_regs.sv"
    cd $root
    return
}
set fo [open qsa_regs_bug.sv w]
puts -nonewline $fo $t
close $fo
set f [list $R/qsa_pe.sv $R/qsa_array.sv $R/qsa_requant.sv $R/qsa_core.sv]
set o1 ""
set o2 ""
set o3 ""
catch {exec xvlog -sv -L uvm {*}$f qsa_regs_bug.sv $R/qsa_top.sv qsa_uvm_s2_tb.sv} o1
catch {exec xelab -L uvm top -s bug3_snap} o2
catch {exec xsim bug3_snap -runall} o3
file delete qsa_regs_bug.sv
set line "NO RESULT LINE FOUND"
regexp {\*\*\* QSA UVM2 TEST [A-Z]+ \*\*\* checks=[0-9]+ errors=[0-9]+} $o3 line
puts $line
cd $root
