derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -setup 2
set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -hold 1

set_multicycle_path -from {emu|SDRAM|sd_refresh*} -setup 2
set_multicycle_path -from {emu|SDRAM|sd_refresh*} -hold 1
set_multicycle_path -from {emu|SDRAM|reset*} -setup 2
set_multicycle_path -from {emu|SDRAM|reset*} -hold 1
