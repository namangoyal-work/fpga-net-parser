test:
	iverilog -g2012 -o sim.vvp tb/axis_passthrough_tb.sv rtl/axis_passthrough.sv
	vvp sim.vvp
waves: test
	gtkwave dump.vcd &
clean:
	rm -f sim.vvp dump.vcd
