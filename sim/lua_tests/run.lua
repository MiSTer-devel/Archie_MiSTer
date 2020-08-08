package.path = package.path .. ";./../lualib/?.lua"
package.path = package.path .. ";./../luatools/?.lua"
require("vsim_comm")

reg_set_file("../releases/riscos.rom", DUMMYREG, 0x400000, 0)

reg_set_connection(0x81, DUMMYREG)
wait_ns(10000)
reg_set_connection(0x80, DUMMYREG)
wait_ns(100000)

reg_set_connection(0x81, DUMMYREG)
wait_ns(10000)
reg_set_connection(0x80, DUMMYREG)
wait_ns(50000)

reg_set_connection(0x81, DUMMYREG)
wait_ns(10000)
reg_set_connection(0x80, DUMMYREG)
wait_ns(60000)

reg_set_connection(0x81, DUMMYREG)
wait_ns(10000)
reg_set_connection(0x80, DUMMYREG)
wait_ns(70000)

reg_set_connection(0x81, DUMMYREG)
wait_ns(10000)
reg_set_connection(0x80, DUMMYREG)
wait_ns(80000)

reg_set_connection(0x81, DUMMYREG)
wait_ns(10000)
reg_set_connection(0x80, DUMMYREG)
wait_ns(90000)

reg_set_connection(0x81, DUMMYREG)
wait_ns(10000)
reg_set_connection(0x80, DUMMYREG)
wait_ns(100000)