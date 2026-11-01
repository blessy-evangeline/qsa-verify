# break_k_uvm3.tcl : control-core bug: an illegal K (0 or above 256) is accepted as legal.
# UVM stage 3a must FAIL on this broken copy. Run from the repo root:
#     cd D:/VivadoProjects/qsa_verify
#     source scripts/break_k_uvm3.tcl
set root [pwd]
cd $root/tb/uvm
set R $root/rtl
set fi [open $R/qsa_core.sv r]
set t [read $fi]
close $fi
set old {(k_i != 9'd0) && (k_i <= 9'd256)}
set new {1'b1}
set t [string map [list $old $new] $t]
if {[string first $old $t] != -1} {
    puts "REPLACE FAILED: the text was not found in rtl/qsa_core.sv"
    cd $root
    return
}
set fo [open qsa_core_bug.sv w]
puts -nonewline $fo $t
close $fo
set f [list $R/qsa_pe.sv $R/qsa_array.sv $R/qsa_requant.sv]
lappend f $R/qsa_regs.sv $R/qsa_top.sv
set o1 ""
set o2 ""
set o3 ""
catch {exec xvlog -sv -L uvm {*}$f qsa_core_bug.sv qsa_uvm_s3_tb.sv} o1
catch {exec xelab -L uvm top -s bug4_snap} o2
catch {exec xsim bug4_snap -runall} o3
file delete qsa_core_bug.sv
set line "NO RESULT LINE FOUND"
regexp {\*\*\* QSA UVM3 TEST [A-Z]+ \*\*\* checks=[0-9]+ errors=[0-9]+} $o3 line
puts $line
cd $root
