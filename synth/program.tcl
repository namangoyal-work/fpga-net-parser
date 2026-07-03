set here [file dirname [info script]]
read_verilog -sv [glob $here/../rtl/*.sv]
read_xdc $here/arty_a7.xdc
synth_design -top fpga_top -part xc7a100tcsg324-1
opt_design
place_design
route_design
report_utilization    -file $here/../docs/utilization_fpga.rpt
report_timing_summary -file $here/../docs/timing_fpga.rpt
write_bitstream -force $here/../docs/fpga_top.bit
