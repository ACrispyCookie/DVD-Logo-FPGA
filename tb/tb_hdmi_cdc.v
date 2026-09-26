`timescale 1ns/1ps

module video_clock_generator(input clk_in, input reset, output pixel_clk, output serial_clk, output locked);
    assign pixel_clk = clk_in;
    assign serial_clk = clk_in;
    assign locked = !reset;
endmodule
module InputDebouncer(input clk, input reset, input input_bounce, output debounced, output posedge_pulse);
    assign debounced = input_bounce;
    assign posedge_pulse = 1'b0;
endmodule
module rgb2dvi_0(
    input aRst_n, input SerialClk, input PixelClk, input vid_pHSync,
    input vid_pVSync, input [23:0] vid_pData, input vid_pVDE,
    output [2:0] TMDS_Data_p, output [2:0] TMDS_Data_n,
    output TMDS_Clk_p, output TMDS_Clk_n
);
    assign TMDS_Data_p = 3'b0; assign TMDS_Data_n = 3'b0;
    assign TMDS_Clk_p = 1'b0; assign TMDS_Clk_n = 1'b0;
endmodule
module renderer(
    input clk, input reset, input edit_mode, input accel_mode,
    input up_ctrl, input down_ctrl, input left_ctrl, input right_ctrl,
    input signed [11:0] x_accel, input signed [11:0] y_accel,
    input frame_end, output write_enable, output [19:0] write_address,
    output [2:0] write_data
);
    assign write_enable=1'b0; assign write_address=20'd0; assign write_data=3'd0;
endmodule
module pixel_controller #(parameter UPSCALE_WIDTH=3)(
    input clk, input reset, input write_enable, input [19:0] write_address,
    input [2:0] write_data, input hrgb_enabled, input vrgb_enabled,
    input [10:0] hpixel, input [UPSCALE_WIDTH-1:0] hpixel_upscale_counter,
    input [10:0] vpixel, output [2:0] rgb
);
    assign rgb=3'b0;
endmodule
module gsync_controller #(
    parameter COUNTER_WIDTH=10, PULSE_CYCLES=1, BACK_PORCH_CYCLES=1,
    DISPLAY_CYCLES=1, FRONT_PORCH_CYCLES=1, UPSCALE_WIDTH=1,
    UPSCALE_CYCLES=1, RESET_PIXEL=1
)(
    input clk, input reset, input enable, output sync, output rgb_enabled,
    output [10:0] pixel, output [UPSCALE_WIDTH-1:0] upscale_counter,
    output frame_end
);
    assign sync=1'b0; assign rgb_enabled=1'b0; assign pixel=11'd0;
    assign upscale_counter={UPSCALE_WIDTH{1'b0}}; assign frame_end=1'b0;
endmodule

module tb_hdmi_cdc;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg signed [11:0] x_accel = 12'sd0;
    reg signed [11:0] y_accel = 12'sd0;
    wire [2:0] hdmi_tx_p, hdmi_tx_n;
    wire hdmi_clk_p, hdmi_clk_n;

    always #5 clk = ~clk;

    hdmi_controller dut(
        .clk(clk), .reset(reset), .enable(1'b1),
        .edit_mode(1'b0), .accel_mode(1'b1),
        .x_accel(x_accel), .y_accel(y_accel),
        .up_ctrl(1'b0), .down_ctrl(1'b0), .left_ctrl(1'b0), .right_ctrl(1'b0),
        .hdmi_tx_p(hdmi_tx_p), .hdmi_tx_n(hdmi_tx_n),
        .hdmi_clk_p(hdmi_clk_p), .hdmi_clk_n(hdmi_clk_n)
    );

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        @(posedge clk); #1;
        if (dut.pixel_reset !== 1'b1)
            $fatal(1, "pixel reset deasserted before synchronization");
        @(posedge clk); #1;
        if (dut.pixel_reset !== 1'b0)
            $fatal(1, "pixel reset did not deassert after two pixel clocks");

        x_accel = 12'sd768;
        y_accel = -12'sd512;
        @(posedge clk); #1;
        if (dut.x_accel_sync !== 12'sd0 || dut.y_accel_sync !== 12'sd0)
            $fatal(1, "accelerometer bypassed the first CDC stage");
        @(posedge clk); #1;
        if (dut.x_accel_sync !== 12'sd768 || dut.y_accel_sync !== -12'sd512)
            $fatal(1, "accelerometer did not cross after two pixel clocks");

        $display("PASS: pixel reset and accelerometer buses cross through two stages");
        $finish;
    end
endmodule
