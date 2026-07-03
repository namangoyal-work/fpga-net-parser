SIM             ?= icarus
TOPLEVEL_LANG    = verilog
COMPILE_ARGS    += -g2012
VERILOG_SOURCES  = $(PWD)/../rtl/axis_passthrough.sv
TOPLEVEL         = axis_passthrough
MODULE           = test_axis_passthrough
include $(shell cocotb-config --makefiles)/Makefile.sim
