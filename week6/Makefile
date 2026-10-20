PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
RTL = rtl/cm0.v rtl/cm1.v rtl/fir_filter.v rtl/fir_filter_combined.v

.PHONY: all generate test simulate analyze clean

all: analyze

generate:
	$(PYTHON) scripts/generate_chirp.py

test:
	mkdir -p sim/build
	$(IVERILOG) -g2012 -Wall -s tb_fir -o sim/build/tb_fir.vvp $(RTL) sim/tb_fir.v
	$(VVP) sim/build/tb_fir.vvp
	mkdir -p sim/build
	$(IVERILOG) -g2012 -Wall -s tb_chirp -o sim/build/tb_chirp.vvp $(RTL) sim/tb_chirp.v
	cd sim && $(VVP) build/tb_chirp.vvp

simulate: generate test

analyze: simulate
	$(PYTHON) scripts/analyze_response.py

clean:
	rm -rf sim/build scripts/__pycache__
