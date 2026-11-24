# ============================================================================
# run_score.do - the high score tracker (friend's logic) on its own
# Run from the PROJECT folder:   vsim -do sim/run_score.do
# Transcript ends with SCORE TRACKER PASS.
# ============================================================================
quit -sim
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog rtl/score_tracker.v sim/tb_score.v
vsim -onfinish stop work.tb_score

add wave -divider {Inputs}
add wave sim:/tb_score/clk
add wave sim:/tb_score/new_game
add wave -radix unsigned sim:/tb_score/add
add wave sim:/tb_score/game_end
add wave -divider {Score}
add wave -radix unsigned sim:/tb_score/score
add wave -radix unsigned sim:/tb_score/high_score

run -all
wave zoom full
