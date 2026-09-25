# DVD Logo FPGA

![Verilog](https://img.shields.io/badge/Verilog-RTL-blue)
![Vivado](https://img.shields.io/badge/Xilinx-Vivado-F15B2A)
![HDMI](https://img.shields.io/badge/HDMI-640%C3%97480-purple)
![FPGA](https://img.shields.io/badge/FPGA-Smart_Zynq_SL-teal)

A Verilog HDMI graphics demo that renders a BRAM-backed DVD logo, moves it across the screen, reflects it at each boundary, and changes its color on collisions. The design outputs a 640×480 HDMI signal from a 128×96 logical framebuffer, with each logical pixel enlarged 5× in both dimensions.

## From ECE333 Lab 4 to HDMI

This project extends the final system from [ECE333 — Digital Systems Lab](https://github.com/ACrispyCookie/ECE333-Digital-Systems-Lab). In that course repository, Lab 3 introduced the VGA timing and BRAM graphics pipeline, while the custom Lab 4 extension connected an SPI accelerometer to the sprite renderer so physical board movement could control an on-screen image.

This standalone design carries that graphics work forward in a different direction:

- VGA output is replaced by HDMI through the Digilent RGB-to-DVI pipeline.
- The framebuffer and sprite remain BRAM-backed.
- The 51×23 DVD logo moves automatically and changes color when it hits an edge.
- Edit mode allows direct movement with the directional inputs.
- Sprite updates are synchronized to completed frames to avoid changing position during active rendering.
- Collision handling keeps the complete sprite, including its final ROM row, inside the 128×96 logical display.

## Architecture

```text
buttons
  │
  ▼
input synchronization / debouncing
  │
  ▼
sprite_controller ── position, direction, collision, color
  │
  ▼
renderer + sprite_vram ── rebuild 128×96 RGB framebuffer
  │
  ▼
pixel_controller ── read framebuffer and upscale 5×
  │
  ├── horizontal / vertical sync controllers
  │
  ▼
24-bit RGB + sync ── rgb2dvi_0 ── HDMI TMDS output
```

### Display pipeline

- [`src/sprite_controller.v`](src/sprite_controller.v) owns the logo position, automatic direction, manual controls, collision response, and color sequence.
- [`src/renderer.v`](src/renderer.v) scans the logical framebuffer and combines the sprite mask with its current color.
- [`src/vram/`](src/vram/) contains the sprite ROM and the red, green, and blue framebuffer planes implemented with Xilinx `RAMB18E1` primitives.
- [`src/pixel_controller.v`](src/pixel_controller.v) addresses the logical framebuffer while the sync controllers expand each logical pixel to a 5×5 block.
- [`src/hdmi/gsync_fsm.v`](src/hdmi/gsync_fsm.v) and [`src/hdmi/gsync_controller.v`](src/hdmi/gsync_controller.v) generate the 640×480 timing and frame boundary used by the animation.
- [`src/hdmi_controller.v`](src/hdmi_controller.v) is the top-level module and connects clocking, controls, rendering, video timing, and HDMI serialization.

## Repository layout

```text
.
├── README.md
├── smart-zynq-sl.xdc       # board clock, controls, and HDMI pin mapping
└── src/
    ├── hdmi_controller.v   # top-level design
    ├── renderer.v          # framebuffer redraw engine
    ├── pixel_controller.v  # framebuffer reader and 5× upscaler
    ├── sprite_controller.v # motion, controls, collision, and color
    ├── debouncers/          # input synchronizers and debouncers
    ├── hdmi/                # horizontal/vertical timing logic
    └── vram/                # sprite ROM and RGB framebuffer BRAMs
```

## Controls

The top-level ports expose:

| Input | Function |
| --- | --- |
| `reset` | Reset input, adapted for the board's active-low reset button in the top level. |
| `edit_mode` | Select manual positioning instead of automatic animation. |
| `up_ctrl` | Move the logo upward in edit mode. |
| `down_ctrl` | Move the logo downward in edit mode. |
| `left_ctrl` | Move the logo left in edit mode. |
| `right_ctrl` | Move the logo right in edit mode. |

The inputs are synchronized and debounced in the pixel-clock domain before they reach the renderer.

## Requirements

For the complete FPGA design:

- Xilinx Vivado
- Smart Zynq SL board files or the equivalent device selection
- Digilent `rgb2dvi` IP
- Vivado Clocking Wizard IP

For lightweight RTL checks:

- Icarus Verilog, or
- Verilator

## Vivado setup

The repository contains the hand-written RTL and board constraints, but not generated Vivado IP output products. To recreate the project:

1. Create a Vivado RTL project for the target Smart Zynq SL device.
2. Add the Verilog sources from `src/` and its `debouncers/`, `hdmi/`, and `vram/` directories.
3. Add [`smart-zynq-sl.xdc`](smart-zynq-sl.xdc) as the constraints file.
4. Generate a Clocking Wizard instance named `clk_wiz_0` with the ports used by [`src/hdmi_controller.v`](src/hdmi_controller.v):
   - `clk_in1`
   - `clk_out1` for the pixel clock
   - `clk_out2` for the 5× serial clock
   - `locked`
5. Add the Digilent RGB-to-DVI IP and name the instance `rgb2dvi_0`.
6. Set `hdmi_controller` as the top-level module.
7. Run synthesis, implementation, bitstream generation, and program the board.

The supplied constraint declares a 50 MHz input clock. For the current 640×480 timing, configure the clock outputs for the pixel clock and its 5× TMDS serialization clock used by the RGB-to-DVI block.

## Lightweight RTL checks

The vendor-independent controller modules can be checked without a Vivado project:

```bash
iverilog -g2012 -Wall -tnull src/sprite_controller.v
iverilog -g2012 -Wall -tnull \
  src/hdmi/gsync_fsm.v \
  src/hdmi/gsync_controller.v

verilator --lint-only -Wall src/sprite_controller.v
```

Full top-level elaboration requires the generated `clk_wiz_0` and `rgb2dvi_0` modules together with the Xilinx simulation libraries for the `RAMB18E1` primitives.

## Design lineage

The commit history preserves the HDMI controller's development from its original introduction in the ECE338 parallel-computer-architecture project: initial framebuffer and timing logic, the first custom TMDS path, migration to Digilent's HDMI IP, timing and reset corrections, and the later collision and sprite-boundary fixes. The underlying graphics architecture traces back to the VGA and accelerometer-controlled sprite work in ECE333 Lab 4.
