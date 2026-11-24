# ============================================================================
# run_game.do - projectile motion, collisions, levels and scoring
# Run from the PROJECT folder:   vsim -do sim/run_game.do
#
# Time is sped up (one video frame = ~100 clocks), so whole shots fit in the
# wave window. bird_y is also drawn as a graph: screen y counts DOWN the screen,
# so the flight arc shows up as a dip (rises = goes down on the graph).
# Transcript lists every shot and ends with GAME PASS.
#
# Optional screenshots:  vsim -c work.tb_game +SNAP   then   python sim/dump2png.py frame_*.txt
# ============================================================================
quit -sim
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog rtl/game_logic.v rtl/level_data.v rtl/score_tracker.v rtl/renderer.v rtl/sprite_rom.v sim/tb_game.v
vsim -onfinish stop work.tb_game

if {[catch {radix define game_states {
        3'd0 "TITLE", 3'd1 "LOAD", 3'd2 "AIM", 3'd3 "FLY",
        3'd4 "SETTLE", 3'd5 "CLEAR", 3'd6 "OVER", 3'd7 "WIN",
        -default unsigned }}]} { set sr unsigned } else { set sr game_states }

add wave -divider {Inputs}
add wave sim:/tb_game/key_press
add wave -label power      -radix unsigned sim:/tb_game/power
add wave -label angle_sw   -radix unsigned {sim:/tb_game/sw[7:4]}
add wave -divider {Game}
add wave -radix $sr        sim:/tb_game/state
add wave -radix unsigned   sim:/tb_game/level
add wave -radix unsigned   sim:/tb_game/bird
add wave -divider {Projectile}
add wave -radix decimal    sim:/tb_game/bird_x
add wave -radix decimal    sim:/tb_game/bird_y
add wave -label bird_y_graph -radix decimal -format analog-step -height 90 -min -20 -max 200 sim:/tb_game/bird_y
add wave -label vel_x -radix decimal sim:/tb_game/g/vel_x
add wave -label vel_y -radix decimal sim:/tb_game/g/vel_y
add wave -divider {World}
add wave -radix binary     sim:/tb_game/pig_alive
add wave -radix binary     sim:/tb_game/blk_alive
add wave -divider {Score}
add wave -radix unsigned   sim:/tb_game/pts_add
add wave                   sim:/tb_game/game_end
add wave -radix unsigned   sim:/tb_game/score
add wave -radix unsigned   sim:/tb_game/high_score

run -all
wave zoom full
