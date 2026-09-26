`timescale 1ns/1ps

module renderer (
    input wire clk,
    input wire reset,
    input wire edit_mode,
    input wire accel_mode,
    input wire up_ctrl,
    input wire down_ctrl,
    input wire left_ctrl,
    input wire right_ctrl,
    input wire signed [11:0] x_accel,
    input wire signed [11:0] y_accel,
    input wire frame_end,
    output reg write_enable,
    output reg [19:0] write_address,
    output reg [2:0] write_data
);
    `include "video_config.vh"

    localparam WAIT = 1'b0;
    localparam WRITE = 1'b1;
    localparam [10:0] SPRITE_WIDTH = 11'd51;
    localparam [10:0] SPRITE_HEIGHT = 11'd23;
    localparam [19:0] FRAMEBUFFER_LAST = VIDEO_FRAME_PIXELS - 1;
    localparam [10:0] FRAMEBUFFER_MAX_X = VIDEO_FRAME_WIDTH - 1;
    localparam [10:0] FRAMEBUFFER_MAX_Y = VIDEO_FRAME_HEIGHT - 1;

    reg current_state, next_state;
    reg [10:0] write_x, write_y;
    reg [13:0] sprite_read_address;
    wire [19:0] start_pos, end_pos;
    wire [10:0] sprite_x, sprite_y;
    wire sprite_out;
    wire sprite_r, sprite_g, sprite_b;
    wire sprite_inside = write_x >= sprite_x
                         && write_x < sprite_x + SPRITE_WIDTH
                         && write_y >= sprite_y
                         && write_y < sprite_y + SPRITE_HEIGHT;

    sprite_vram sprite_vram_inst(
        .clk(clk), .reset(reset),
        .read_address(sprite_read_address), .out(sprite_out)
    );

    sprite_controller #(
        .X_BOUNDARY(FRAMEBUFFER_MAX_X),
        .Y_BOUNDARY(FRAMEBUFFER_MAX_Y)
    ) sprite_controller_inst (
        .clk(clk), .reset(reset), .edit_mode(edit_mode),
        .accel_mode(accel_mode), .x_accel(x_accel), .y_accel(y_accel),
        .frame_end(frame_end), .up_ctrl(up_ctrl), .down_ctrl(down_ctrl),
        .left_ctrl(left_ctrl), .right_ctrl(right_ctrl),
        .start_pos(start_pos), .end_pos(end_pos),
        .sprite_x(sprite_x), .sprite_y(sprite_y),
        .r(sprite_r), .g(sprite_g), .b(sprite_b)
    );

    // The sprite ROM keeps its original 128-bit row stride. Framebuffer
    // geometry changes independently, so map framebuffer coordinates back to
    // that fixed sprite layout before the synchronous ROM read.
    always @(*) begin
        if (write_enable && sprite_inside)
            sprite_read_address = ({3'd0, (write_y - sprite_y)} << 7)
                                  + {3'd0, (write_x - sprite_x)} + 14'd1;
        else
            sprite_read_address = 14'd0;
    end

    always @(*) begin
        if (write_enable && sprite_inside)
            write_data = sprite_out ? {sprite_r, sprite_g, sprite_b} : 3'b0;
        else
            write_data = 3'b0;
    end

    always @(posedge clk) begin
        if (reset || !write_enable) begin
            write_address <= 20'd0;
            write_x <= 11'd0;
            write_y <= 11'd0;
        end else begin
            write_address <= write_address + 20'd1;
            if (write_x == FRAMEBUFFER_MAX_X) begin
                write_x <= 11'd0;
                if (write_y == FRAMEBUFFER_MAX_Y)
                    write_y <= 11'd0;
                else
                    write_y <= write_y + 11'd1;
            end else begin
                write_x <= write_x + 11'd1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset)
            current_state <= WRITE;
        else
            current_state <= next_state;
    end

    always @(*) begin
        case (current_state)
            WAIT: next_state = frame_end ? WRITE : WAIT;
            WRITE: next_state = write_address == FRAMEBUFFER_LAST ? WAIT : WRITE;
            default: next_state = WAIT;
        endcase
    end

    always @(*) begin
        case (current_state)
            WAIT: write_enable = 1'b0;
            WRITE: write_enable = 1'b1;
            default: write_enable = 1'b0;
        endcase
    end
endmodule
