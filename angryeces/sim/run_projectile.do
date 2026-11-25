# run_projectile.do - projectile X and Y at the fixed initial scale
# Run from the project folder: vsim -do sim/run_projectile.do
quit -sim
if {![file exists rtl/game_logic.v] && [file exists ../rtl/game_logic.v]} { cd .. }
if {![file exists rtl/game_logic.v]} {
    error "Run this from the angryeces folder (the one holding rtl/ and sim/). Current folder: [pwd]"
}
if {![file exists work]} { vlib work }
vlog rtl/game_logic.v rtl/level_data.v rtl/collision.v sim/tb_projectile.v
vsim -onfinish stop work.tb_projectile

if {[catch {radix define game_states {
        3'd0 "TITLE", 3'd1 "LOAD", 3'd2 "AIM", 3'd3 "FLY",
        3'd4 "SETTLE", 3'd5 "CLEAR", 3'd6 "OVER", 3'd7 "WIN",
        -default unsigned }}]} { set sr unsigned } else { set sr game_states }

set tb sim:/tb_projectile
add wave -divider {Inputs}
add wave $tb/key_press
add wave -radix unsigned $tb/power
add wave -radix unsigned $tb/g/arc_scale
add wave -divider {Launch}
add wave -radix unsigned $tb/g/clamped_power
add wave -radix unsigned $tb/g/speed_x
add wave -radix decimal $tb/g/launch_velocity_x
add wave -radix decimal $tb/g/launch_velocity_y
add wave -divider {Flight}
add wave -radix $sr $tb/state
add wave -radix unsigned $tb/bird
add wave $tb/g/col_pause
add wave $tb/g/on_ground
add wave -divider {X}
add wave -radix decimal $tb/g/velocity_x
add wave -radix decimal $tb/g/position_x
add wave -radix decimal $tb/bird_x
add wave -label bird_x_graph -radix decimal -format analog-step -height 90 -min 0 -max 330 $tb/bird_x
add wave -divider {Y}
add wave -radix decimal $tb/g/velocity_y
add wave -radix decimal $tb/g/position_y
add wave -radix decimal $tb/bird_y
add wave -label bird_y_graph -radix decimal -format analog-step -height 90 -min -20 -max 200 $tb/bird_y
add wave -divider {Aim dots}
add wave -radix unsigned $tb/dot_x_f
add wave -radix unsigned $tb/dot_y_f
add wave -radix binary $tb/dot_on
add wave -divider {Expected}
add wave -radix decimal $tb/shot_power
add wave -radix decimal $tb/moves
add wave -radix decimal $tb/expected_vx
add wave -radix decimal $tb/expected_vy
add wave -radix decimal $tb/expected_pos_x
add wave -radix decimal $tb/expected_pos_y
add wave -radix decimal $tb/expected_bird_x
add wave -radix decimal $tb/expected_bird_y
add wave -radix decimal $tb/errors

run -all
wave zoom full
