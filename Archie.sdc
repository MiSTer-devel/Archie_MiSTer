derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -setup 2
set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -hold 1
