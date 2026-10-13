vlib work
vlog ../rtl/part1.v ../rtl/part1_modified.v ../rtl/part2.v ../rtl/part3.v
vlog -sv tb_sequences.v
vsim work.tb_sequences
run -all
