`timescale 1ns/1ps

module hdmi_controller (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire edit_mode,
    input wire accel_mode,
    input wire signed [11:0] x_accel,
    input wire signed [11:0] y_accel,
    input wire up_ctrl,
    input wire down_ctrl,
    input wire left_ctrl,
    input wire right_ctrl,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    output wire hdmi_clk_p,
    output wire hdmi_clk_n
);
    `include "video_config.vh"

    wire clk_pixel, clk_pixel_x5, locked;
    (* ASYNC_REG = "TRUE" *) reg reset_meta = 1'b1;
    (* ASYNC_REG = "TRUE" *) reg pixel_reset = 1'b1;
    (* ASYNC_REG = "TRUE" *) reg signed [11:0] x_accel_meta = 12'sd0;
    (* ASYNC_REG = "TRUE" *) reg signed [11:0] x_accel_sync = 12'sd0;
    (* ASYNC_REG = "TRUE" *) reg signed [11:0] y_accel_meta = 12'sd0;
    (* ASYNC_REG = "TRUE" *) reg signed [11:0] y_accel_sync = 12'sd0;
    wire debounced_enable, debounced_edit, debounced_accel;
    wire up_debounced, down_debounced, left_debounced, right_debounced;
    wire hsync_raw, vsync_raw;
    wire hsync = VIDEO_H_SYNC_POSITIVE ? ~hsync_raw : hsync_raw;
    wire vsync = VIDEO_V_SYNC_POSITIVE ? ~vsync_raw : vsync_raw;
    wire frame_end;
    wire [2:0] rgb;
    wire [10:0] hpixel, vpixel;
    wire [VIDEO_H_UPSCALE_WIDTH-1:0] hpixel_upscale_counter;
    wire hrgb_enabled, vrgb_enabled;
    wire active_draw = hrgb_enabled & vrgb_enabled;
    wire [23:0] rgb24 = {
        {8{rgb[2]}},
        {8{rgb[0]}},
        {8{rgb[1]}}
    };
    wire write_enable;
    wire [19:0] write_address;
    wire [2:0] write_data;

    video_clock_generator clock_inst(
        .clk_in(clk), .reset(reset),
        .pixel_clk(clk_pixel), .serial_clk(clk_pixel_x5), .locked(locked)
    );

    // Assert reset immediately, then release it only after two pixel-clock
    // edges. Accelerometer samples are stable between sensor updates, so a
    // two-stage bus sample contains that CDC at the pixel-domain boundary.
    always @(posedge clk_pixel or posedge reset) begin
        if (reset) begin
            reset_meta <= 1'b1;
            pixel_reset <= 1'b1;
        end else begin
            reset_meta <= 1'b0;
            pixel_reset <= reset_meta;
        end
    end

    always @(posedge clk_pixel or posedge pixel_reset) begin
        if (pixel_reset) begin
            x_accel_meta <= 12'sd0;
            x_accel_sync <= 12'sd0;
            y_accel_meta <= 12'sd0;
            y_accel_sync <= 12'sd0;
        end else begin
            x_accel_meta <= x_accel;
            x_accel_sync <= x_accel_meta;
            y_accel_meta <= y_accel;
            y_accel_sync <= y_accel_meta;
        end
    end

    InputDebouncer enable_debouncer_inst(.clk(clk_pixel), .reset(pixel_reset), .input_bounce(enable), .debounced(debounced_enable), .posedge_pulse());
    InputDebouncer edit_debouncer_inst(.clk(clk_pixel), .reset(pixel_reset), .input_bounce(edit_mode), .debounced(debounced_edit), .posedge_pulse());
    InputDebouncer accel_debouncer_inst(.clk(clk_pixel), .reset(pixel_reset), .input_bounce(accel_mode), .debounced(debounced_accel), .posedge_pulse());
    InputDebouncer up_debouncer_inst(.clk(clk_pixel), .reset(pixel_reset), .input_bounce(up_ctrl), .debounced(up_debounced), .posedge_pulse());
    InputDebouncer down_debouncer_inst(.clk(clk_pixel), .reset(pixel_reset), .input_bounce(down_ctrl), .debounced(down_debounced), .posedge_pulse());
    InputDebouncer left_debouncer_inst(.clk(clk_pixel), .reset(pixel_reset), .input_bounce(left_ctrl), .debounced(left_debounced), .posedge_pulse());
    InputDebouncer right_debouncer_inst(.clk(clk_pixel), .reset(pixel_reset), .input_bounce(right_ctrl), .debounced(right_debounced), .posedge_pulse());

    rgb2dvi_0 rgb_inst(
        .aRst_n(locked && !pixel_reset),
        .SerialClk(clk_pixel_x5),
        .PixelClk(clk_pixel),
        .vid_pHSync(hsync),
        .vid_pVSync(vsync),
        .vid_pData(rgb24),
        .vid_pVDE(active_draw),
        .TMDS_Clk_p(hdmi_clk_p),
        .TMDS_Clk_n(hdmi_clk_n),
        .TMDS_Data_p(hdmi_tx_p),
        .TMDS_Data_n(hdmi_tx_n)
    );

    renderer renderer_inst(
        .clk(clk_pixel), .reset(pixel_reset),
        .accel_mode(debounced_accel), .edit_mode(debounced_edit),
        .up_ctrl(up_debounced), .down_ctrl(down_debounced),
        .left_ctrl(left_debounced), .right_ctrl(right_debounced),
        .x_accel(x_accel_sync), .y_accel(y_accel_sync), .frame_end(frame_end),
        .write_enable(write_enable), .write_address(write_address),
        .write_data(write_data)
    );

    pixel_controller #(
        .UPSCALE_WIDTH(VIDEO_H_UPSCALE_WIDTH)
    ) pixel_controller_inst(
        .clk(clk_pixel), .reset(pixel_reset),
        .write_enable(write_enable), .write_address(write_address),
        .write_data(write_data), .hrgb_enabled(hrgb_enabled),
        .vrgb_enabled(vrgb_enabled), .hpixel(hpixel),
        .hpixel_upscale_counter(hpixel_upscale_counter),
        .vpixel(vpixel), .rgb(rgb)
    );

    gsync_controller #(
        .COUNTER_WIDTH(VIDEO_H_COUNTER_WIDTH),
        .PULSE_CYCLES(VIDEO_H_SYNC - 1),
        .BACK_PORCH_CYCLES(VIDEO_H_BACK_PORCH - 1),
        .DISPLAY_CYCLES(VIDEO_H_ACTIVE - 1),
        .FRONT_PORCH_CYCLES(VIDEO_H_FRONT_PORCH - 1),
        .UPSCALE_WIDTH(VIDEO_H_UPSCALE_WIDTH),
        .UPSCALE_CYCLES(`VIDEO_UPSCALE - 1),
        .RESET_PIXEL(VIDEO_FRAME_WIDTH)
    ) hsync_controller_inst(
        .clk(clk_pixel), .reset(pixel_reset), .enable(debounced_enable),
        .sync(hsync_raw), .rgb_enabled(hrgb_enabled), .pixel(hpixel),
        .upscale_counter(hpixel_upscale_counter), .frame_end()
    );

    gsync_controller #(
        .COUNTER_WIDTH(VIDEO_V_COUNTER_WIDTH),
        .PULSE_CYCLES(VIDEO_V_SYNC * VIDEO_H_TOTAL - 1),
        .BACK_PORCH_CYCLES(VIDEO_V_BACK_PORCH * VIDEO_H_TOTAL - 1),
        .DISPLAY_CYCLES(VIDEO_V_ACTIVE * VIDEO_H_TOTAL - 1),
        .FRONT_PORCH_CYCLES(VIDEO_V_FRONT_PORCH * VIDEO_H_TOTAL - 1),
        .UPSCALE_WIDTH(VIDEO_V_UPSCALE_WIDTH),
        .UPSCALE_CYCLES(`VIDEO_UPSCALE * VIDEO_H_TOTAL - 1),
        .RESET_PIXEL(VIDEO_FRAME_HEIGHT)
    ) vsync_controller_inst(
        .clk(clk_pixel), .reset(pixel_reset), .enable(debounced_enable),
        .sync(vsync_raw), .rgb_enabled(vrgb_enabled), .pixel(vpixel),
        .upscale_counter(), .frame_end(frame_end)
    );
endmodule
