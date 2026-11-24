# ============================================================================
# run_top.do - the whole board design at real speed
# Run from the PROJECT folder:   vsim -do sim/run_top.do
# KEY1 starts, the slingshot sends '9' on GPIO_1[0], one VGA frame is saved to
# frame_top.txt, KEY1 launches. Slow (~85 ms of sim time). Ends with TOP PASS.
# View the frame:  python sim/dump2png.py frame_top.txt
# ============================================================================
quit -sim
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog rtl/vga_timing.v rtl/slingshot_rx.v rtl/score_tracker.v rtl/char_to_7seg.v \
     rtl/game_logic.v rtl/level_data.v rtl/sprite_rom.v rtl/renderer.v rtl/screen_rom.v \
     rtl/angry_eces_top.v sim/tb_top.v
vsim -onfinish stop work.tb_top

if {[catch {radix define game_states {
        3'd0 "TITLE", 3'd1 "LOAD", 3'd2 "AIM", 3'd3 "FLY",
        3'd4 "SETTLE", 3'd5 "CLEAR", 3'd6 "OVER", 3'd7 "WIN",
        -default unsigned }}]} { set sr unsigned } else { set sr game_states }

add wave -divider {Board inputs}
add wave -label KEY                       sim:/tb_top/KEY
add wave -label slingshot_GPIO_1_0        sim:/tb_top/rx_line
add wave -divider {Slingshot}
add wave -label slider  -radix unsigned   sim:/tb_top/dut/sling_value
add wave -label connected                 sim:/tb_top/dut/sling_seen
add wave -label power   -radix unsigned   sim:/tb_top/dut/power
add wave -divider {Game}
add wave -radix $sr     sim:/tb_top/dut/state
add wave -radix decimal sim:/tb_top/dut/bird_x
add wave -radix decimal sim:/tb_top/dut/bird_y
add wave -radix unsigned sim:/tb_top/dut/score
add wave -radix unsigned sim:/tb_top/dut/high_score
add wave -divider {Board outputs}
add wave -label HEX0 -radix binary        sim:/tb_top/HEX0
add wave -label LEDR -radix binary        sim:/tb_top/LEDR
add wave sim:/tb_top/VGA_HS
add wave sim:/tb_top/VGA_VS

run -all
wave zoom full
