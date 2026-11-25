# run_obstacle_flash.do - obstacle flash and removal when the bird's hitbox overlaps one
# Run from the project folder: vsim -do sim/run_obstacle_flash.do
quit -sim
if {![file exists rtl/game_logic.v] && [file exists ../rtl/game_logic.v]} { cd .. }
if {![file exists rtl/game_logic.v]} {
    error "Run this from the angryeces folder (the one holding rtl/ and sim/). Current folder: [pwd]"
}
if {![file exists work]} { vlib work }
vlog rtl/game_logic.v rtl/level_data.v rtl/collision.v sim/tb_obstacle_flash.v
vsim -onfinish stop work.tb_obstacle_flash

if {[catch {radix define game_states {
        3'd0 "TITLE", 3'd1 "LOAD", 3'd2 "AIM", 3'd3 "FLY",
        3'd4 "SETTLE", 3'd5 "CLEAR", 3'd6 "OVER", 3'd7 "WIN",
        -default unsigned }}]} { set sr unsigned } else { set sr game_states }
if {[catch {radix define obstacle_states {
        2'd0 "IDLE", 2'd1 "FLY", 2'd2 "FLASH", 2'd3 "REMOVE",
        -default unsigned }}]} { set cr unsigned } else { set cr obstacle_states }

set tb sim:/tb_obstacle_flash
set col $tb/g/collision_inst
add wave -divider {Game}
add wave -radix $sr $tb/state
add wave $tb/bird_vis
add wave -radix decimal $tb/bird_x
add wave -radix decimal $tb/bird_y
add wave -label bird_y_graph -radix decimal -format analog-step -height 90 -min -20 -max 200 $tb/bird_y
add wave -radix decimal $tb/g/velocity_y
add wave -divider {Overlap detection}
add wave $col/any_hit
add wave -radix binary $col/pig_pick
add wave -radix binary $col/block_pick
add wave -divider {Collision FSM}
add wave -radix $cr $col/col_state
add wave -radix unsigned $col/flash_timer
add wave -radix unsigned $col/health
add wave $col/pause
add wave $col/spent
add wave -divider {Flash and removal}
add wave -radix binary $tb/pig_flash
add wave -radix binary $tb/blk_flash
add wave -radix binary $col/pig_kill
add wave -radix binary $col/blk_kill
add wave -radix binary $tb/pig_alive
add wave -radix binary $tb/blk_alive
add wave -divider {Score}
add wave -radix unsigned $tb/pts_add
add wave -radix decimal $tb/total_pts
add wave -radix decimal $tb/errors

run -all
wave zoom full
