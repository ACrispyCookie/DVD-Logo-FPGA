`timescale 1ns/1ps
module tb_video_config;
    `include "video_config.vh"

    initial begin
        if (`VIDEO_UPSCALE < 1)
            $fatal(1, "upscale must be positive");
        if ((VIDEO_H_ACTIVE % `VIDEO_UPSCALE) != 0 ||
            (VIDEO_V_ACTIVE % `VIDEO_UPSCALE) != 0)
            $fatal(1, "upscale must divide the selected active resolution");

        if (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_480P) begin
            if (VIDEO_H_ACTIVE != 640 || VIDEO_V_ACTIVE != 480)
                $fatal(1, "480p active dimensions are incorrect");
            if (VIDEO_PIXEL_CLOCK_KHZ != 25175)
                $fatal(1, "480p pixel clock selection is incorrect");
        end else if (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) begin
            if (VIDEO_H_ACTIVE != 1280 || VIDEO_V_ACTIVE != 720)
                $fatal(1, "720p active dimensions are incorrect");
            if (VIDEO_PIXEL_CLOCK_KHZ != 74250)
                $fatal(1, "720p pixel clock selection is incorrect");
        end else begin
            $fatal(1, "unknown resolution preset");
        end

        if (VIDEO_FRAME_WIDTH != VIDEO_H_ACTIVE / `VIDEO_UPSCALE ||
            VIDEO_FRAME_HEIGHT != VIDEO_V_ACTIVE / `VIDEO_UPSCALE)
            $fatal(1, "logical framebuffer is not derived from upscale");
        if (VIDEO_FRAME_PIXELS != VIDEO_FRAME_WIDTH * VIDEO_FRAME_HEIGHT)
            $fatal(1, "framebuffer size is not derived from its dimensions");

        $display("PASS: resolution preset and upscale independently derive the design");
        $finish;
    end
endmodule
