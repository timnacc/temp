vlib work
vlog ../rtl/part4.v
vlog -sv tb_morse.v
vsim -gTICK_CYCLES=4 work.tb_morse
run -all
