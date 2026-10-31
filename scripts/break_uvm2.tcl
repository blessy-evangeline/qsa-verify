# break_uvm2.tcl : wiring bug (zero point never reaches the core).
# UVM stage 2a must FAIL on this broken copy. Run from the repo root:
#     cd D:/VivadoProjects/qsa_verify
#     source scripts/break_uvm2.tcl
set root [pwd]
cd $root/tb/uvm
set R $root/rtl
set fi [open $R/qsa_top.sv r]
set t [read $fi]
close $fi
set old {.zp_i(zp_w)}
set new {.zp_i(8'sd0)}
set t [string map [list $old $new] $t]
if {[string first {.zp_i(8'sd0)} $t] == -1} {
    puts "REPLACE FAILED: the text .zp_i(zp_w) was not found in rtl/qsa_top.sv"
    cd $root
    return
}
set fo [open qsa_top_bug.sv w]
puts -nonewline $fo $t
close $fo
set f [list $R/qsa_pe.sv $R/qsa_array.sv $R/qsa_requant.sv $R/qsa_core.sv $R/qsa_regs.sv]
set o1 ""
set o2 ""
set o3 ""
catch {exec xvlog -sv -L uvm {*}$f qsa_top_bug.sv qsa_uvm_s2_tb.sv} o1
catch {exec xelab -L uvm top -s bug2_snap} o2
catch {exec xsim bug2_snap -runall} o3
file delete qsa_top_bug.sv
set line "NO RESULT LINE FOUND"
regexp {\*\*\* QSA UVM2 TEST [A-Z]+ \*\*\* checks=[0-9]+ errors=[0-9]+} $o3 line
puts $line
cd $root
