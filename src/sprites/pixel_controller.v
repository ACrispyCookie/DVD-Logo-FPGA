`timescale 1ns/1ps

module pixel_controller #(
    parameter UPSCALE_WIDTH = 3
) (
    input wire clk,
    input wire reset,
    input wire write_enable,
    input wire [19:0] write_address,
    input wire [2:0] write_data,
    input wire hrgb_enabled,
    input wire vrgb_enabled,
    input wire [10:0] hpixel,
    input wire [UPSCALE_WIDTH-1:0] hpixel_upscale_counter,
    input wire [10:0] vpixel,
    output reg [2:0] rgb
);
    `include "video_config.vh"

    wire rgb_enabled = hrgb_enabled & vrgb_enabled;
    wire [19:0] current_address = vpixel * VIDEO_FRAME_WIDTH + hpixel;
    localparam [19:0] FRAMEBUFFER_LAST = VIDEO_FRAME_PIXELS - 1;
    reg [19:0] vram_address;
    wire vram_r, vram_g, vram_b;

    vram vram_inst(
        .clk(clk), .reset(reset),
        .write_enable(write_enable), .write_address(write_address),
        .write_data(write_data), .read_address(vram_address),
        .r(vram_r), .g(vram_g), .b(vram_b)
    );

    always @(*) begin
        if (rgb_enabled && hpixel_upscale_counter == `VIDEO_UPSCALE - 1
            && current_address < FRAMEBUFFER_LAST)
            vram_address = current_address + 20'd1;
        else
            vram_address = current_address;
    end

    always @(*) begin
        if (rgb_enabled)
            rgb = {vram_r, vram_g, vram_b};
        else
            rgb = 3'b0;
    end
endmodule
