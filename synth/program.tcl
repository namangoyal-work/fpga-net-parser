open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
refresh_hw_device $dev
set_property PROGRAM.FILE {docs/fpga_top.bit} $dev
program_hw_devices $dev
puts "PROGRAMMED"
