# Conservative 20 ns constraint; real KEY0 edges are manual and much slower.
create_clock -name manual_clock -period 20.000 [get_ports {KEY[0]}]
derive_clock_uncertainty
