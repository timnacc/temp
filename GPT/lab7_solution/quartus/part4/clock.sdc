create_clock -name board_clock -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty
