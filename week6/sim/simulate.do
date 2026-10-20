onerror {quit -code 1}
if {![file isdirectory work]} {vlib work}
vlog ../rtl/cm0.v ../rtl/cm1.v ../rtl/fir_filter.v ../rtl/fir_filter_combined.v
vlog -sv tb_fir.v tb_chirp.v
vsim -onfinish stop work.tb_fir
run -all
quit -sim
vsim -onfinish stop work.tb_chirp
run -all
