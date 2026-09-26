// User-facing display configuration.
// Change only these two defaults; all timing, clocks, and framebuffer geometry
// are derived from them. Command-line -D overrides are supported for tests.
`define VIDEO_RESOLUTION_480P 0
`define VIDEO_RESOLUTION_720P 1

`ifndef VIDEO_RESOLUTION
`define VIDEO_RESOLUTION `VIDEO_RESOLUTION_720P
`endif

`ifndef VIDEO_UPSCALE
`define VIDEO_UPSCALE 1
`endif

// Derived mode constants. This file is included inside the modules that need
// video geometry, so these remain implementation details rather than ports.
localparam integer VIDEO_H_ACTIVE =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 1280 : 640;
localparam integer VIDEO_H_FRONT_PORCH =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 110 : 16;
localparam integer VIDEO_H_SYNC =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 40 : 96;
localparam integer VIDEO_H_BACK_PORCH =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 220 : 48;
localparam integer VIDEO_V_ACTIVE =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 720 : 480;
localparam integer VIDEO_V_FRONT_PORCH =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 5 : 10;
localparam integer VIDEO_V_SYNC =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 5 : 2;
localparam integer VIDEO_V_BACK_PORCH =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 20 : 33;
localparam VIDEO_H_SYNC_POSITIVE =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P);
localparam VIDEO_V_SYNC_POSITIVE =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P);
localparam integer VIDEO_PIXEL_CLOCK_KHZ =
    (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) ? 74250 : 25175;

localparam integer VIDEO_H_TOTAL = VIDEO_H_ACTIVE + VIDEO_H_FRONT_PORCH
                                   + VIDEO_H_SYNC + VIDEO_H_BACK_PORCH;
localparam integer VIDEO_V_TOTAL = VIDEO_V_ACTIVE + VIDEO_V_FRONT_PORCH
                                   + VIDEO_V_SYNC + VIDEO_V_BACK_PORCH;
localparam integer VIDEO_FRAME_WIDTH = VIDEO_H_ACTIVE / `VIDEO_UPSCALE;
localparam integer VIDEO_FRAME_HEIGHT = VIDEO_V_ACTIVE / `VIDEO_UPSCALE;
localparam integer VIDEO_FRAME_PIXELS = VIDEO_FRAME_WIDTH * VIDEO_FRAME_HEIGHT;
localparam integer VIDEO_H_COUNTER_WIDTH = $clog2(VIDEO_H_TOTAL);
localparam integer VIDEO_V_COUNTER_WIDTH = $clog2(VIDEO_V_TOTAL * VIDEO_H_TOTAL);
localparam integer VIDEO_H_UPSCALE_WIDTH =
    (`VIDEO_UPSCALE <= 1) ? 1 : $clog2(`VIDEO_UPSCALE);
localparam integer VIDEO_V_UPSCALE_WIDTH = $clog2(`VIDEO_UPSCALE * VIDEO_H_TOTAL);
