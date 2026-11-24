# ============================================================================
# run_slingshot.do - the slingshot UART receiver (friend's code) on its own
# Run from the PROJECT folder:   vsim -do sim/run_slingshot.do
#   (ModelSim window: File > Change Directory > project folder, then: do sim/run_slingshot.do)
# Sends '7', '3', 'A', 'f', newline, '0'. Transcript ends with SLINGSHOT UART PASS.
# ============================================================================
quit -sim
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog rtl/slingshot_rx.v sim/tb_slingshot_rx.v
vsim -onfinish stop work.tb_slingshot_rx

add wave -divider {UART line}
add wave -label rx_pin                   sim:/tb_slingshot_rx/rx_line
add wave -label rx_final                 sim:/tb_slingshot_rx/dut/rx_final
add wave -divider {UART RX FSM}
add wave -label rx_state  -radix binary  sim:/tb_slingshot_rx/dut/state
add wave -label clk_count -radix unsigned sim:/tb_slingshot_rx/dut/clk_count
add wave -label bit_count -radix unsigned sim:/tb_slingshot_rx/dut/bit_count
add wave -label rx_shift_reg -radix hex  sim:/tb_slingshot_rx/dut/rx_shift_reg
add wave -label rx_data   -radix ascii   sim:/tb_slingshot_rx/dut/rx_data
add wave -label rx_valid                 sim:/tb_slingshot_rx/dut/rx_valid
add wave -divider {Output}
add wave -label slider    -radix unsigned sim:/tb_slingshot_rx/hex_value
add wave -label seen                     sim:/tb_slingshot_rx/seen

run -all
wave zoom full
