create_clock -name sample_clk -period 1000000.000 [get_ports {clk}]
derive_clock_uncertainty
