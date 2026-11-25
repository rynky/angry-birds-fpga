# run_vertical_scale.do - parabola vertical scaling with KEY2 (taller) and KEY3 (flatter)
# Run from the project folder: vsim -do sim/run_vertical_scale.do
quit -sim
if {![file exists rtl/game_logic.v] && [file exists ../rtl/game_logic.v]} { cd .. }
if {![file exists rtl/game_logic.v]} {
    error "Run this from the angryeces folder (the one holding rtl/ and sim/). Current folder: [pwd]"
}
if {![file exists work]} { vlib work }
vlog rtl/game_logic.v rtl/level_data.v rtl/collision.v sim/tb_vertical_scale.v
vsim -onfinish stop work.tb_vertical_scale

if {[catch {radix define game_states {
        3'd0 "TITLE", 3'd1 "LOAD", 3'd2 "AIM", 3'd3 "FLY",
        3'd4 "SETTLE", 3'd5 "CLEAR", 3'd6 "OVER", 3'd7 "WIN",
        -default unsigned }}]} { set sr unsigned } else { set sr game_states }

set tb sim:/tb_vertical_scale
add wave -divider {Keys}
add wave -label KEY2_up $tb/key_up
add wave -label KEY3_down $tb/key_down
add wave $tb/key_press
add wave -divider {Arc scale}
add wave -radix $sr $tb/state
add wave -radix unsigned $tb/g/arc_scale
add wave -label arc_scale_graph -radix unsigned -format analog-step -height 70 -min 0 -max 140 $tb/g/arc_scale
add wave -divider {Flight}
add wave -radix decimal $tb/g/position_y
add wave -radix decimal $tb/bird_x
add wave -radix decimal $tb/bird_y
add wave -label bird_y_graph -radix decimal -format analog-step -height 90 -min -20 -max 200 $tb/bird_y
add wave $tb/g/on_ground
add wave -divider {Aim dots}
add wave -radix unsigned $tb/dot_y_f
add wave -radix binary $tb/dot_on
add wave -divider {Results}
add wave -radix decimal $tb/peak_y
add wave -radix decimal $tb/shot_peak
add wave -radix decimal $tb/errors

run -all
wave zoom full
