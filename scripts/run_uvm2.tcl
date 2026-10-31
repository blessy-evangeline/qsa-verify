# run_uvm2.tcl : build and run UVM stage 2, print only the result line and the first errors.
# Run from the repo root in the Vivado Tcl Shell:
#     cd D:/VivadoProjects/qsa_verify
#     source scripts/run_uvm2.tcl
set root [pwd]
cd $root/tb/uvm
set R $root/rtl
set f [list $R/qsa_pe.sv $R/qsa_array.sv $R/qsa_requant.sv $R/qsa_core.sv $R/qsa_regs.sv $R/qsa_top.sv]
set o1 ""
set o2 ""
set o3 ""
catch {exec xvlog -sv -L uvm {*}$f qsa_uvm_s2_tb.sv} o1
catch {exec xelab -L uvm top -s uvm2_snap} o2
catch {exec xsim uvm2_snap -runall} o3
file mkdir $root/results/logs
set fh [open $root/results/logs/uvm2_debug.log w]
puts $fh "== xvlog ==\n$o1\n== xelab ==\n$o2\n== xsim ==\n$o3"
close $fh
set errs {}
set res "NO RESULT LINE FOUND"
foreach line [split $o3 "\n"] {
    if {[regexp {\*\*\* QSA UVM2 TEST [A-Z]+ \*\*\*.*} $line m]} {
        set res $m
    } elseif {[regexp {UVM_ERROR .*(CHECK_FAILED|K register|REG_RESP|REG_DATA|bad output)} $line] && [llength $errs] < 6} {
        lappend errs $line
    }
}
foreach e $errs { puts $e }
puts $res
if {$res eq "NO RESULT LINE FOUND"} {
    puts "Compile output tail:"
    puts [string range $o1 end-700 end]
    puts "Elaborate output tail:"
    puts [string range $o2 end-500 end]
}
cd $root
