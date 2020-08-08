RMDIR /s /q work
MKDIR work

vmap altera_mf altera_mf

vlib work

vlog -O0 +incdir+./../rtl/  ../rtl/archimedes_top.v ^
../rtl/memc.v ^
../rtl/memc_translator.v ^
../rtl/vidc.v ^
../rtl/vidc_audio.v ^
../rtl/vidc_dmachannel.v ^
../rtl/vidc_fifo.v ^
../rtl/vidc_timing.v ^
../rtl/ioc.v ^
../rtl/ioc_irq.v ^
../rtl/fdc1772.v ^
../rtl/floppy.v ^
../rtl/latches.v ^
../rtl/sram_line_en.v ^
../rtl/sram_byte_en.v ^
../rtl/podules.v

vlog -O0 +incdir+./../rtl/amber/  ../rtl/amber/a23_alu.v ^
../rtl/amber/a23_barrel_shift.v ^
../rtl/amber/a23_barrel_shift_fpga.v ^
../rtl/amber/a23_cache.v ^
../rtl/amber/a23_config_defines.v ^
../rtl/amber/a23_coprocessor.v ^
../rtl/amber/a23_core.v ^
../rtl/amber/a23_decode.v ^
../rtl/amber/a23_execute.v ^
../rtl/amber/a23_fetch.v ^
../rtl/amber/a23_multiply.v ^
../rtl/amber/a23_ram_register_bank.v ^
../rtl/amber/a23_register_bank.v ^
../rtl/amber/a23_wishbone.v

vcom -O5 -2008 -vopt -quiet -work work ^
../rtl/bram.vhd

vcom -O5 -2008 -vopt -quiet -work work ^
cpu_export.vhd

vcom -O5 -vopt -quiet -work work ^
globals.vhd ^
stringprocessor.vhd ^
tb.vhd

