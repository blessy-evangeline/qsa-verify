# run_all.tcl : compile, elaborate and run every QSA-Verify test, saving a log for each.
# Run from the repo root in the Vivado Tcl Shell:
#     cd D:/VivadoProjects/qsa_verify
#     source run_all.tcl
# Logs go to results/logs/<test>.txt and results/logs/SUMMARY.txt

set root [pwd]
file mkdir $root/results/logs

proc qsa_run_test {name dir rtl tb top uvm} {
    global root
    set files {}
    foreach f $rtl { lappend files $root/rtl/$f }
    set uv {}
    if {$uvm} { set uv {-L uvm} }
    cd $root/$dir
    set o1 ""
    set o2 ""
    set o3 ""
    catch {exec xvlog -sv {*}$uv {*}$files $tb} o1
    catch {exec xelab {*}$uv $top -s ${name}_snap} o2
    catch {exec xsim ${name}_snap -runall} o3
    set fh [open $root/results/logs/$name.txt w]
    puts $fh "== xvlog ==\n$o1\n== xelab ==\n$o2\n== xsim ==\n$o3"
    close $fh
    set line "NO RESULT LINE FOUND"
    regexp {\*\*\* [A-Z0-9 ]*(PASSED|FAILED) \*\*\* checks=[0-9]+ errors=[0-9]+} $o3 line
    cd $root
    return $line
}

set tests {
    {adder   tb/adder    {}                                                                   add_tb.sv          top             1}
    {mac     tb/mac      {}                                                                   mac_tb.sv          top             1}
    {pe      tb/pe       {qsa_pe.sv}                                                          qsa_pe_tb.sv       qsa_pe_tb       0}
    {array   tb/array    {qsa_pe.sv qsa_array.sv}                                             qsa_array_tb.sv    qsa_array_tb    0}
    {requant tb/requant  {qsa_requant.sv}                                                     qsa_requant_tb.sv  qsa_requant_tb  0}
    {core    tb/core     {qsa_pe.sv qsa_array.sv qsa_requant.sv qsa_core.sv}                  qsa_core_tb.sv     qsa_core_tb     0}
    {regs    tb/regs     {qsa_regs.sv}                                                        qsa_regs_tb.sv     qsa_regs_tb     0}
    {top     tb/top      {qsa_pe.sv qsa_array.sv qsa_requant.sv qsa_core.sv qsa_regs.sv qsa_top.sv} qsa_top_tb.sv qsa_top_tb 0}
    {uvm1    tb/uvm      {qsa_pe.sv qsa_array.sv qsa_requant.sv qsa_core.sv}                  qsa_uvm_tb.sv      top             1}
    {uvm2    tb/uvm      {qsa_pe.sv qsa_array.sv qsa_requant.sv qsa_core.sv qsa_regs.sv qsa_top.sv} qsa_uvm_s2_tb.sv top 1}
}

set summary ""
set allpass 1
foreach t $tests {
    lassign $t name dir rtl tb top uvm
    set line [qsa_run_test $name $dir $rtl $tb $top $uvm]
    if {![string match "*PASSED*" $line]} { set allpass 0 }
    append summary [format "%-8s %s\n" $name $line]
    puts [format "%-8s %s" $name $line]
}
if {$allpass} { append summary "\nALL TESTS PASSED\n" } else { append summary "\nSOME TESTS FAILED\n" }
puts $summary
set fh [open $root/results/logs/SUMMARY.txt w]
puts -nonewline $fh $summary
close $fh
