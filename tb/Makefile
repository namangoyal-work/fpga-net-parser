DUT ?= axis_skid
SIM ?= icarus
TOPLEVEL_LANG = verilog
COMPILE_ARGS += -g2012
VERILOG_SOURCES = $(wildcard $(PWD)/../rtl/*.sv)
TOPLEVEL = $(DUT)
COCOTB_TEST_MODULES ?= test_$(DUT)
SIM_BUILD = sim_build_$(DUT)
include $(shell cocotb-config --makefiles)/Makefile.sim
