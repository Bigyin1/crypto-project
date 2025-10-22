# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

EXTRA_ARGS += --trace --trace-structs

VERILOG_SOURCES += src/sha256_pkg.sv src/sha256.sv 
# use VHDL_SOURCES for VHDL files

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
COCOTB_TOPLEVEL = sha256

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
COCOTB_TEST_MODULES = test.tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
