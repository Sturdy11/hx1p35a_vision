if {[catch {
set scene116_project_directory {__PROJECT_ROOT__}
set scene116_build_directory {__BUILD_ROOT__}
file mkdir {__BUILD_ROOT__}
cd {__BUILD_ROOT__}
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
import_db {__BUILD_ROOT__/build116_place.db}
set_param flow thread auto
set_param route aware_critical on
set_param route level_base_optimize on
update_timing -mode manhattan
set_param route effort normal
set_param route timing on
set_param route fix_hold on
set_param route post_route_opt ultra
set_param route postrt_opt_extra_round 4
route
export_db build116_routed.db
update_timing -mode final
report_timing_summary -file build116_route.timing
report_timing_status -file build116_route.ts
report_area -io_info -file build116_phy.area
set timing_channel [open build116_route.ts r]
set timing_text [read $timing_channel]
close $timing_channel
foreach metric {SWNS HWNS} {
 if {![regexp [format {%s:\s*([-0-9.]+)ns} $metric] $timing_text -> slack]} {error "Missing timing metric $metric"}
 if {$slack < 0.0} {error "Timing failed: $metric=$slack ns; bitgen skipped"}
}
set_param bitgen compress on
bitgen -bit BUILD116_compare_stable.bit
puts {DONE rc=0}
} failure]} {
 puts "BUILD116 FAILED: $failure"
 exit 1
}
exit 0
