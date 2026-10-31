# run_uvm2.tcl : build and run UVM stage 2a, print only the lines that matter.
# Run from the repo root in the Vivado Tcl Shell:
#     cd D:/VivadoProjects/qsa_verify
#     source run_uvm2.tcl
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
set fh [open $root/results/logs/uvm2_debug.txt w]
puts $fh "== xvlog ==\n$o1\n== xelab ==\n$o2\n== xsim ==\n$o3"
close $fh
set n 0
foreach line [split $o3 "\n"] {
    if {[regexp {shadow write|start: snapshot|K register|CHECK_FAILED|QSA UVM2} $line]} {
        puts $line
        incr n
        if {$n >= 14} { break }
    }
}
if {$n == 0} {
    puts "NO MATCHING LINES. Compile output tail:"
    puts [string range $o1 end-700 end]
    puts "Elaborate output tail:"
    puts [string range $o2 end-500 end]
}
cd $root
