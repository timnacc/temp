vlib work
vlog ../rtl/part1.v ../rtl/part1_modified.v ../rtl/part2.v ../rtl/part3.v ../rtl/part3_single.v tb_sequence.v
vsim work.tb_sequence
add wave -r /*
run -all
