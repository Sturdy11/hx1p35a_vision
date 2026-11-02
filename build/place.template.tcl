if {[catch {
set scene116_project_directory {__PROJECT_ROOT__}
set scene116_build_directory {__BUILD_ROOT__}
file mkdir {__BUILD_ROOT__}
cd {__BUILD_ROOT__}
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
set_param flow thread 4
open_project {__BUILD_ROOT__/project.al}
elaborate -top design_top_wrapper116
read_adc {__PROJECT_ROOT__/board/pin.adc}
read_ip_adc -ip ddr2 -file {__PROJECT_ROOT__/src/ip/ddr2/src/adc/ddr2.adc}
read_sdc {__PROJECT_ROOT__/board/video.sdc}
read_sdc -ip ddr2 {__PROJECT_ROOT__/src/ip/ddr2/src/sdc/ddr2.sdc}
read_sdc -ip w128_d512_fifo {__PROJECT_ROOT__/src/ip/w128_d512_fifo/w128_d512_fifo.tcl}
set_param gate add_map_lut_struct high
set_param gate map_mode area_prior
set_param gate multi_thread_mapping partition
set_param rtl resource_sharing auto
set_param rtl shifter_style shifter_reg
optimize_rtl
optimize_gate -packarea build116_gate.area
export_db build116_gate.db
set_param flow thread 4
set_param place seed 3
legalize_phy_inst
set_param place pr_strategy 11
set_param place macro_performance macro_congestion
set_param place preplace_floorplan on
set_param place effort high
set_param place opt_timing high
set_param place logic_level_opt on
set_param place aggressive_opt 21
set_param place aggr_neighbor_dist 5
set_param place enhanced_beeline_opt 3
set_param place timing_driven_mode on
set_param place shifter_opt on
set_param place crit_path_opt on
set_param place post_place_opt high
set_param place hfn_opt_effort high
set_param place split_data_from_clock on
set_param place enhanced_gp off
place
export_db build116_first_place.db
update_timing -mode manhattan
export_db build116_place.db
report_timing_summary -ep_num 16 -path_num 1 -file build116_place.timing
report_area -file build116_place.area
puts {PLACE116 COMPLETE}
} failure]} {puts "BUILD116 FAILED: $failure";exit 1}
exit 0
