// Reconfigurable native video PLL.
//
// The PLL starts at the Mode 23 parent frequency so TimeQuest
// analyses the complete video domain. The runtime controller selects the
// parent frequency required by the programmed VIDC base-clock family.
module video_pll (
	input  wire        refclk,
	input  wire        rst,
	output wire        outclk,
	output wire        locked,
	input  wire [63:0] reconfig_to_pll,
	output wire [63:0] reconfig_from_pll
);

	altera_pll #(
		.fractional_vco_multiplier("true"),
		.reference_clock_frequency("50.0 MHz"),
		.pll_fractional_cout(32),
		.pll_dsm_out_sel("1st_order"),
		.operation_mode("direct"),
		.number_of_clocks(1),
		.output_clock_frequency0("96.000000 MHz"),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		.pll_type("Cyclone V"),
		.pll_subtype("Reconfigurable"),
		// 50 MHz * (11 + 0.52) / 6 = 96 MHz.
		.m_cnt_hi_div(6), .m_cnt_lo_div(5),
		.n_cnt_hi_div(256), .n_cnt_lo_div(256),
		.m_cnt_bypass_en("false"), .n_cnt_bypass_en("true"),
		.m_cnt_odd_div_duty_en("true"), .n_cnt_odd_div_duty_en("false"),
		.c_cnt_hi_div0(3), .c_cnt_lo_div0(3),
		.c_cnt_prst0(1), .c_cnt_ph_mux_prst0(0),
		.c_cnt_in_src0("ph_mux_clk"),
		.c_cnt_bypass_en0("false"), .c_cnt_odd_div_duty_en0("false"),
		.pll_vco_div(2),
		.pll_cp_current(20), .pll_bwctrl(4000),
		.pll_output_clk_frequency("576.000000 MHz"),
		.pll_fractional_division("2233382994"),
		.mimic_fbclk_type("gclk"),
		.pll_fbclk_mux_1("glb"), .pll_fbclk_mux_2("m_cnt"),
		.pll_m_cnt_in_src("ph_mux_clk"), .pll_slf_rst("true")
	) altera_pll_i (
		.rst      (rst),
		.outclk   (outclk),
		.locked   (locked),
		.reconfig_to_pll   (reconfig_to_pll),
		.reconfig_from_pll (reconfig_from_pll),
		.fboutclk (),
		.fbclk    (1'b0),
		.refclk   (refclk)
	);

endmodule
