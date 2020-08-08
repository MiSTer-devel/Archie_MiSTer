Tested with Modelsim 10.5

- compile with vcom_all.bat. Make sure you have altera_mf library in folder, generated from quartus
- run modelsim with vsim_start.bat
- run all

Simulation will now wait for input from outside

Run Luascript run.lua with "lua run.lua" from folder lua_tests

It will upload riscos into the testbench memory and let the cpu run it

Current test checks for reset working.

CPU Export will write a log with every register change for every clock cycle.
This can be used to compare(with a diff tool) original behavior to any changes made.
