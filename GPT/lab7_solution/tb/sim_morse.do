vlib work
vlog ../rtl/part4.v tb_morse.v
vsim work.tb_morse
add wave -r /*
run -all
