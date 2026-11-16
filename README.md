# Angry Birds FPGA Edition

## Introduction

This project is an Angry Birds-style slingshot game written in Verilog HDL for the Altera DE1-SoC FPGA board. The game logic, projectile FSM, graphics rendering and scoring all run in hardware, with video output over VGA and the score shown on the 7-segment displays.

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
