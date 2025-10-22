# Author: Piotr Otfinowski

set parts [get_parts]
create_project UFERI_comm ./proj -part [lindex $parts 0] -force 

add_files -scan_for_includes [glob -nocomplain ./rtl/*.sv]
update_compile_order -fileset sources_1

add_files -fileset sim_1 -scan_for_includes [glob -nocomplain ./dv/*.sv]
set_property top tb_top.sv [get_filesets sim_1]
update_compile_order -fileset sim_1