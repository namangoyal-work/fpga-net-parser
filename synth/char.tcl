# Out-of-context characterization of the parser pipeline.
set here [file dirname [info script]]
set part xc7a100tcsg324-1

read_verilog -sv [glob $here/../rtl/*.sv]
synth_design -top parser_top -part $part -mode out_of_context
create_clock -name clk -period 4.000 [get_ports clk]   ;# probe at 250 MHz

opt_design
place_design
route_design

report_utilization    -file $here/../docs/utilization.rpt
report_timing_summary -file $here/../docs/timing.rpt
puts "=== timing headline (read WNS below) ==="
report_timing_summary -no_header -no_detailed_paths
