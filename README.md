# Angry Birds FPGA Edition

This project is an Angry Birds-style slingshot game written in Verilog HDL for the Altera DE1-SoC FPGA board with video output over VGA.

The player sets the bird's launch arc with a custom physical controller built around a slider potentiometer. The signal path is:

```
Slider Potentiometer → Arduino (ATmega32u4) → 5V-to-3.3V I2C Converter → FPGA GPIO Pins
```

The board's keys select the bird sprite and its switches select the level.

## System Overview

```
┌─────────────────┐
│ Key (Sprites)   │──┐   ┌──────────────────┐       ┌─────────────────┐
└─────────────────┘  ├──►│ Level, Sprite    │───┬───│ Slingshot Input │
┌─────────────────┐  │   │ Inputs           │   │   └─────────────────┘
│ Switch (Levels) │──┘   └──────────────────┘   │
└─────────────────┘                             │
                                                ▼
┌─────────────────┐      ┌──────────────────────────┐      ┌──────────────────┐
│ Clock & Reset   │─────►│ Game Logic &             │─────►│ Score Module     │
│ Module          │      │ Projectile FSM           │      │ (Counters)       │
└────────┬────────┘      └────────────┬─────────────┘      └────────┬─────────┘
         │                            │                             │
         ▼                            │                             ▼
┌─────────────────┐                   │                   ┌───────────────────┐
│ Graphics        │◄──────────────────┘                   │ 7-Segment Display │
│ Renderer        │                                       └───────────────────┘
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ VGA Output      │
│ (Monitor)       │
└─────────────────┘
```

## UART Hex Display for the Altera DE1-SoC over GPIO Pins

```
GPIO_1[0] -> CYCLE SYNCHRONIZER -> UART FSM -> ascii_to_hex -> char_to_7seg -> HEX0
 (rx_pin)        (rx_final)        (rx_data)    (hex_value)
```
- **UART receiver:** a 9600 baud, 8N1 receiver on `GPIO_1[0]` with a 2 flip-flop synchronizer. It samples each bit at its midpoint, while checking for false starts and stops.
- **`ascii_to_hex`:** latches `0-9`, `A-F` and `a-f` ASCII codes as a 4-bit value and ignores any other character.
- **`char_to_7seg`:** decodes that value to an active-low 7-segment output.
