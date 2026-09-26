# DVD Logo FPGA

![Verilog](https://img.shields.io/badge/Verilog-RTL-blue)
![Vivado](https://img.shields.io/badge/Xilinx-Vivado-F15B2A)
![HDMI](https://img.shields.io/badge/HDMI-640%C3%97480-purple)
![FPGA](https://img.shields.io/badge/FPGA-Smart_Zynq_SL-teal)

An interactive FPGA graphics system for the Smart Zynq SL. It renders a complete 51×23 DVD logo from BRAM, drives a 640×480 HDMI display, and supports automatic bouncing, push-button positioning, or motion control from the board's SPI accelerometer. Sensor readings are also formatted and streamed over UART at 57,600 baud.

The renderer works on a 128×96 logical framebuffer and expands every logical pixel into a 5×5 block. Position updates occur between completed frames, while bounded coordinate arithmetic keeps the full sprite on screen and changes its color when it reaches an edge.

## From ECE333 Lab 4 to HDMI

This project develops the display and accelerometer work from [ECE333 — Digital Systems Lab](https://github.com/ACrispyCookie/ECE333-Digital-Systems-Lab) into a standalone HDMI design. Lab 3 established the VGA timing and BRAM graphics pipeline; the custom Lab 4 extension then connected the board's accelerometer to an on-screen sprite.

The current design brings those ideas together on the Smart Zynq SL:

- HDMI replaces VGA through Digilent's RGB-to-DVI encoder and serializer.
- A 51×23 sprite is stored in BRAM and composited into a 128×96 RGB framebuffer.
- Automatic mode reflects the logo at every boundary and cycles its color on impact.
- Accelerometer mode reads signed X/Y motion over 5 MHz SPI and moves the logo with edge clamping.
- Edit mode provides direct four-direction positioning from the board controls.
- X, Y, Z, and temperature measurements are continuously formatted for a UART terminal.

## Architecture

```text
                         ┌─────────────── 57,600-baud UART ───────► TxD
                         │
ADXL362 ── 5 MHz SPI ──► value_reader ── averaging / ASCII formatting
                         │
                         └── signed X/Y acceleration
                                      │
buttons / mode switches ── sync + debounce
                                      │
                                      ▼
                             sprite_controller
                      position • collision • color • modes
                                      │
                                      ▼
                     renderer + sprite/framebuffer BRAM
                                      │
                                      ▼
                      pixel_controller + 5× upscaling
                                      │
                                      ▼
                  640×480 timing ──► rgb2dvi_0 ──► HDMI
```

- [`src/top.v`](src/top.v) connects reset conditioning, SPI acquisition, UART output, and the HDMI subsystem.
- [`src/accelerometer/`](src/accelerometer/) initializes the sensor, reads and averages its channels, and transmits the formatted measurements.
- [`src/sprites/sprite_controller.v`](src/sprites/sprite_controller.v) applies the active control mode, enforces the legal `X=0..77` and `Y=0..73` range, and derives framebuffer addresses.
- [`src/sprites/renderer.v`](src/sprites/renderer.v) combines the current sprite mask and color with the logical framebuffer.
- [`src/sprites/vram/`](src/sprites/vram/) contains the sprite ROM and RGB framebuffer planes built from Xilinx `RAMB18E1` blocks.
- [`src/hdmi/`](src/hdmi/) generates video timing, reads the framebuffer, and feeds 24-bit RGB plus sync signals to `rgb2dvi_0`.

## Repository layout

```text
.
├── README.md
├── smart-zynq-sl.xdc             # clock, controls, SPI, UART, and HDMI pins
├── src/
│   ├── top.v                     # complete board-level integration
│   ├── accelerometer/
│   │   ├── spi/                  # 5 MHz SPI master
│   │   ├── uart/                 # ASCII output and 57,600-baud transmitter
│   │   ├── value_reader.v        # sensor initialization and sample sequencing
│   │   └── avg_calc.v            # X/Y/Z/temperature averaging
│   ├── debouncers/               # reset and control input conditioning
│   ├── hdmi/                     # video timing and HDMI pipeline
│   └── sprites/                  # motion, rendering, sprite ROM, and framebuffer
└── tb/                           # focused SPI, UART, and sprite regressions
```

## Controls

The mode inputs are prioritized as **accelerometer → automatic → edit**. Enabling `accel_mode` therefore overrides `edit_mode`; with acceleration disabled, `edit_mode=0` selects the normal bouncing animation and `edit_mode=1` enables the directional controls.

| Board input | Top-level port | Function |
| --- | --- | --- |
| Reset button | `reset` | Active-low board reset; conditioned into the active-high internal reset. |
| Mode switch | `accel_mode` | Move from signed X/Y accelerometer readings. |
| Mode switch | `edit_mode` | Select manual positioning when accelerometer mode is off. |
| Up button | `up_ctrl` | Move one logical pixel upward in edit mode. |
| Down button | `down_ctrl` | Move one logical pixel downward in edit mode. |
| Left button | `left_ctrl` | Move one logical pixel left in edit mode. |
| Right button | `right_ctrl` | Move one logical pixel right in edit mode. |

Controls are synchronized and debounced before use. Sprite movement is applied on the animation tick derived from the end of a video frame, preventing mid-frame position changes.

## Requirements

- Xilinx Vivado with support for the Smart Zynq SL's `xc7z020clg484-1`
- Digilent RGB-to-DVI IP (`rgb2dvi`)
- Vivado Clocking Wizard IP
- HDMI display and cable
- Serial terminal capable of **57,600 baud, 8 data bits, even parity, 1 stop bit**

## Vivado setup

The repository provides the hand-written RTL and [`smart-zynq-sl.xdc`](smart-zynq-sl.xdc); generated Vivado IP output products are created locally.

1. Create an RTL project targeting `xc7z020clg484-1`.
2. Add every Verilog source under [`src/`](src/) and add [`smart-zynq-sl.xdc`](smart-zynq-sl.xdc).
3. Set [`top`](src/top.v) as the project top module.
4. Generate a Clocking Wizard named `clk_wiz_0` from the 50 MHz board clock with:
   - `clk_out1 = 25.175 MHz` for the 640×480 pixel clock
   - `clk_out2 = 125.875 MHz` for 5× TMDS serialization
   - the `locked` output enabled
5. Add Digilent's RGB-to-DVI IP as `rgb2dvi_0`, configured for the pixel and 5× serial clocks used in [`src/hdmi/hdmi_controller.v`](src/hdmi/hdmi_controller.v).
6. Run synthesis, implementation, and bitstream generation, then program the board.
7. Connect the HDMI output. To observe sensor telemetry as well, open the board's UART output at **57,600 8E1**.

After reset is released, the design initializes the accelerometer, starts periodic sampling, updates the UART display, and supplies signed X/Y values to the sprite controller. Leave both mode switches low for the automatic DVD animation, enable `accel_mode` to steer by tilting the board, or enable `edit_mode` alone for button control.
