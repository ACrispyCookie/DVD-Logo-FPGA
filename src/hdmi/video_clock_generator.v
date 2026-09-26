`timescale 1ns/1ps

module video_clock_generator (
    input wire clk_in,
    input wire reset,
    output wire pixel_clk,
    output wire serial_clk,
    output wire locked
);
    `include "video_config.vh"

    wire feedback;
    wire feedback_buffered;
    wire pixel_unbuffered;
    wire serial_unbuffered;

    generate
        if (`VIDEO_RESOLUTION == `VIDEO_RESOLUTION_720P) begin : mode_720p
            MMCME2_BASE #(
                .BANDWIDTH("OPTIMIZED"),
                .CLKIN1_PERIOD(20.000),
                .DIVCLK_DIVIDE(4),
                .CLKFBOUT_MULT_F(59.375),
                .CLKOUT0_DIVIDE_F(10.000),
                .CLKOUT1_DIVIDE(2),
                .CLKOUT0_DUTY_CYCLE(0.500),
                .CLKOUT1_DUTY_CYCLE(0.500),
                .STARTUP_WAIT("FALSE")
            ) mmcm (
                .CLKIN1(clk_in), .CLKFBIN(feedback_buffered),
                .RST(reset), .PWRDWN(1'b0),
                .CLKFBOUT(feedback), .CLKOUT0(pixel_unbuffered),
                .CLKOUT1(serial_unbuffered), .LOCKED(locked)
            );
        end else begin : mode_480p
            MMCME2_BASE #(
                .BANDWIDTH("OPTIMIZED"),
                .CLKIN1_PERIOD(20.000),
                .DIVCLK_DIVIDE(1),
                .CLKFBOUT_MULT_F(17.625),
                .CLKOUT0_DIVIDE_F(35.000),
                .CLKOUT1_DIVIDE(7),
                .CLKOUT0_DUTY_CYCLE(0.500),
                .CLKOUT1_DUTY_CYCLE(0.500),
                .STARTUP_WAIT("FALSE")
            ) mmcm (
                .CLKIN1(clk_in), .CLKFBIN(feedback_buffered),
                .RST(reset), .PWRDWN(1'b0),
                .CLKFBOUT(feedback), .CLKOUT0(pixel_unbuffered),
                .CLKOUT1(serial_unbuffered), .LOCKED(locked)
            );
        end
    endgenerate

    BUFG feedback_buf (.I(feedback), .O(feedback_buffered));
    BUFG pixel_buf (.I(pixel_unbuffered), .O(pixel_clk));
    BUFG serial_buf (.I(serial_unbuffered), .O(serial_clk));
endmodule
