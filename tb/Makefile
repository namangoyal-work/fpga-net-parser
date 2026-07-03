DUT ?= axis_skid
SIM ?= icarus
TOPLEVEL_LANG = verilog
COMPILE_ARGS += -g2012
VERILOG_SOURCES = $(PWD)/../rtl/$(DUT).sv
TOPLEVEL = $(DUT)
COCOTB_TEST_MODULES ?= test_$(DUT)
include $(shell cocotb-config --makefiles)/Makefile.sim
