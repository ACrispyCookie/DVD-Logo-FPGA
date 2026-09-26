`timescale 1ns/1ps

module vram (
    input wire clk,
    input wire reset,
    input wire write_enable,
    input wire [19:0] write_address,
    input wire [2:0] write_data,
    input wire [19:0] read_address,
    output reg r,
    output reg g,
    output reg b
);
    `include "video_config.vh"

    (* ram_style = "block" *) reg red_memory [0:VIDEO_FRAME_PIXELS-1];
    (* ram_style = "block" *) reg green_memory [0:VIDEO_FRAME_PIXELS-1];
    (* ram_style = "block" *) reg blue_memory [0:VIDEO_FRAME_PIXELS-1];

    always @(posedge clk) begin
        if (write_enable) begin
            red_memory[write_address] <= write_data[2];
            green_memory[write_address] <= write_data[1];
            blue_memory[write_address] <= write_data[0];
        end

        if (reset) begin
            r <= 1'b0;
            g <= 1'b0;
            b <= 1'b0;
        end else begin
            r <= red_memory[read_address];
            g <= green_memory[read_address];
            b <= blue_memory[read_address];
        end
    end
endmodule
