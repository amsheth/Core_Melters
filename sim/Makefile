SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

PKG_SRCS  := $(PWD)/../pkg/types.sv
HDL_SRCS  := $(shell find $(PWD)/../hdl -name '*.sv')
COMM_HVL  := $(shell find $(PWD)/../hvl/common -name '*.sv' -o -name '*.v')
VCS_HVL   := $(COMM_HVL) $(shell find $(PWD)/../hvl/vcs -name '*.sv' -o -name '*.v')
VER_HVL   := $(COMM_HVL) $(shell find $(PWD)/../hvl/verilator -name '*.sv' -o -name '*.v')
SRAM_SRCS := $(shell find $(PWD)/../sram/output -name '*.v')
HDRS      := $(shell find $(PWD)/../hvl -name '*.svh') $(PWD)/../hvl/common/rvfi_reference.json
DW_IP     := $(shell python3 $(PWD)/../bin/get_options.py dw_ip)
VCS_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VCS_HVL) $(SRAM_SRCS) $(DW_IP)
VER_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VER_HVL) $(SRAM_SRCS) $(DW_IP)
VER_EX    := $(PWD)/../hvl/verilator/verilator_harness.cpp

TIMEOUT   ?= 10000000

export VCS_ARCH_OVERRIDE=linux
VCS_FLAGS= -full64 -lca -sverilog -timescale=1ps/1ps -debug_acc+all -kdb -fsdb -suppress=LCA_FEATURES_ENABLED -msg_config=../vcs_warn.config -xprop=../xprop.config -xprop=flowctrl +incdir+$(DW)/sim_ver +define+DW_SUPPRESS_WARN +incdir+$(PWD)/../hvl/vcs +incdir+$(PWD)/../hvl/common
VER_FLAGS= -Wall --timescale 1ps/1ps --trace-structs --trace-max-array 128 --trace-depth 1 -Mdir build -O3 -CFLAGS "-Ofast -march=native" --x-assign fast --x-initial fast --noassert --cc ../verilator_warn.vlt +incdir+$(DW)/sim_ver +define+DW_SUPPRESS_WARN +incdir+$(PWD)/../hvl/vcs +incdir+$(PWD)/../hvl/common

vcs/top_tb: $(VCS_SRCS) $(HDRS)
	mkdir -p vcs
	python3 check_sus.py
	../bin/rvfi_reference.py
	cd vcs && vcs $(VCS_SRCS) $(VCS_FLAGS) -l compile.log -top top_tb -o top_tb
	bash check_compile_error.sh

.PHONY: run_vcs_top_tb
run_vcs_top_tb: vcs/top_tb $(PROG)
	mkdir -p spike
	../bin/generate_memory_file.py -32 $(PROG)
	rm -f vcs/dump.fsdb
	python3 $(PWD)/../bin/get_options.py clock
	python3 $(PWD)/../bin/get_options.py bmem_x
	cd vcs && ./top_tb -l simulation.log -exitstatus \
		+TIMEOUT_ECE411=$(TIMEOUT) \
		+CLOCK_PERIOD_PS_ECE411=$(shell python3 $(PWD)/../bin/get_options.py clock) \
		+MEMLST_ECE411="$(PWD)/bin/memory_32.lst" \
		+BRAM_0_ON_X_ECE411=$(shell python3 $(PWD)/../bin/get_options.py bmem_x)

verilator/build/Vtop_tb: $(VER_SRCS) $(HDRS) $(VER_EX)
	mkdir -p verilator
	python3 check_sus.py
	../bin/rvfi_reference.py
	cd verilator ;\
	verilator -trace-fst +define+ECE411_VER_DUMP +define+ECE411_FST_DUMP $(VER_FLAGS) $(VER_SRCS) --top-module top_tb --exe $(VER_EX)
	cd verilator/build ;\
	$(MAKE) --jobs=$(shell echo $(shell nproc)-2 | bc) -f Vtop_tb.mk

.PHONY: run_verilator_top_tb
run_verilator_top_tb: verilator/build/Vtop_tb $(PROG)
	mkdir -p spike
	find ./verilator -maxdepth 1 -type f -delete
	../bin/generate_memory_file.py -32 $(PROG)
	python3 $(PWD)/../bin/get_options.py clock
	python3 $(PWD)/../bin/get_options.py bmem_x
	cd verilator && ./build/Vtop_tb \
		+TIMEOUT_ECE411=$(TIMEOUT) \
		+CLOCK_PERIOD_PS_ECE411=$(shell python3 $(PWD)/../bin/get_options.py clock) \
		+BRAM_0_ON_X_ECE411=$(shell python3 $(PWD)/../bin/get_options.py bmem_x) \
		+MEMLST_ECE411="$(PWD)/bin/memory_32.lst"

.PHONY: run_verilator_lint
run_verilator_lint: $(VER_SRCS) $(HDRS) $(VER_EX)
	mkdir -p verilator
	python3 check_sus.py
	../bin/rvfi_reference.py
	cd verilator ;\
	verilator --lint-only +define+ECE411_VER_DUMP +define+ECE411_FST_DUMP $(VER_FLAGS) $(VER_SRCS) --top-module top_tb --exe $(VER_EX)

.PHONY: covrep
covrep: vcs/top_tb.vdb
	cd vcs && urg -dir top_tb.vdb

.PHONY: verdi
verdi:
	mkdir -p verdi
	cd verdi && timeout $(ECE411_GUI_TIMEOUT) $(VERDI_HOME)/bin/verdi -ssf $(PWD)/vcs/dump.fsdb

.PHONY: spike
spike: $(ELF)
	mkdir -p spike
	spike --isa=$(shell python3 $(PWD)/../bin/get_options.py arch) -m0x1eceb000:0xe1315000 --log-commits $(ELF) |& tail -n +6 > spike/spike.log

.PHONY: interactive_spike
interactive_spike: $(ELF)
	spike --isa=$(shell python3 $(PWD)/../bin/get_options.py arch) -m0x1eceb000:0xe1315000 --log-commits -d $(ELF)

.PHONY: clean
clean:
	rm -rf bin vcs verdi verilator spike
