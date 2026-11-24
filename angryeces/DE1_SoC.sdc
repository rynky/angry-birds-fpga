# DE1_SoC.sdc - timing constraints (the course QSF points at this file name)
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# h/v and the VGA output registers only change when pix_en = 1 (every 2nd clock),
# so the colour logic has 2 clocks (40 ns) per pixel.
set_multicycle_path -setup -end 2 -from [get_registers {*u_vga|h[*] *u_vga|v[*]}] -to [get_registers {VGA_R[*] VGA_G[*] VGA_B[*]}]
set_multicycle_path -hold  -end 1 -from [get_registers {*u_vga|h[*] *u_vga|v[*]}] -to [get_registers {VGA_R[*] VGA_G[*] VGA_B[*]}]

# buttons, switches and the slingshot UART are asynchronous (synchronised inside);
# LEDs and 7-seg displays are slow outputs
set_false_path -from [get_ports {KEY[*] SW[*] GPIO_1[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*]}]
