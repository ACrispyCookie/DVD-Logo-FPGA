`timescale 1ns/1ps

module sprite_controller #(
    parameter [10:0] X_BOUNDARY = 11'd127,
    parameter [10:0] Y_BOUNDARY = 11'd95,
    parameter [10:0] X_POS = 11'd0,
    parameter [10:0] Y_POS = 11'd0
) (
    clk,
    reset,
    edit_mode,
    accel_mode,
    up_ctrl,
    down_ctrl,
    left_ctrl,
    right_ctrl,
    x_accel,
    y_accel,
    frame_end,
    start_pos,
    end_pos,
    sprite_x,
    sprite_y,
    r,
    g,
    b
);
    localparam [10:0] WIDTH = 11'd51;
    localparam [10:0] HEIGHT = 11'd23;
    localparam [10:0] MAX_X_POS = X_BOUNDARY - WIDTH + 11'd1;
    localparam [10:0] MAX_Y_POS = Y_BOUNDARY - HEIGHT + 11'd1;
    localparam [19:0] ROW_STRIDE = {9'd0, X_BOUNDARY} + 20'd1;
    localparam [19:0] START_POS = ROW_STRIDE * Y_POS + {9'd0, X_POS};
    localparam [19:0] SPRITE_SPAN = ({9'd0, HEIGHT} - 20'd1) * ROW_STRIDE
                                      + ({9'd0, WIDTH} - 20'd1);
    localparam [19:0] END_POS = START_POS + SPRITE_SPAN;
    localparam [1:0] FRAME_INTERVAL = 2'b10;

    input clk, reset, edit_mode, accel_mode;
    input signed [11:0] x_accel, y_accel;
    input up_ctrl, down_ctrl, left_ctrl, right_ctrl;
    input frame_end;
    output reg [19:0] start_pos, end_pos;
    output wire [10:0] sprite_x, sprite_y;
    output wire r, g, b;

    reg [1:0] frame_counter;
    reg [10:0] x_pos, y_pos;
    reg x_moving_right, y_moving_down;
    reg [10:0] auto_next_x_pos, auto_next_y_pos;
    reg auto_next_x_moving_right, auto_next_y_moving_down;
    reg [10:0] accel_next_x_pos, accel_next_y_pos;
    reg accel_next_x_moving_right, accel_next_y_moving_down;
    reg signed [12:0] accel_x_candidate, accel_y_candidate;
    reg accel_horizontal_collision, accel_vertical_collision;
    reg [2:0] color;

    wire animation_tick;
    wire auto_horizontal_collision;
    wire auto_vertical_collision;
    wire movement_collision;
    wire signed [11:0] x_accel_scaled;
    wire signed [11:0] y_accel_scaled;

    assign animation_tick = frame_end && frame_counter == FRAME_INTERVAL;
    assign auto_horizontal_collision = (x_moving_right && x_pos >= MAX_X_POS)
                                     || (!x_moving_right && x_pos == 0);
    assign auto_vertical_collision = (y_moving_down && y_pos >= MAX_Y_POS)
                                   || (!y_moving_down && y_pos == 0);
    assign movement_collision = accel_mode
                              ? (accel_horizontal_collision || accel_vertical_collision)
                              : (!edit_mode
                                 && (auto_horizontal_collision || auto_vertical_collision));

    // Match the Lab 4 control sensitivity: one pixel per 256 raw units.
    assign x_accel_scaled = x_accel >>> 8;
    assign y_accel_scaled = y_accel >>> 8;

    assign sprite_x = x_pos;
    assign sprite_y = y_pos;
    assign r = color[0];
    assign g = color[1];
    assign b = color[2];

    // Compute the next automatic bounce step. At an edge, move back into
    // the valid area immediately instead of applying stale velocity.
    always @(*) begin
        auto_next_x_pos = x_pos;
        auto_next_y_pos = y_pos;
        auto_next_x_moving_right = x_moving_right;
        auto_next_y_moving_down = y_moving_down;

        if (x_moving_right) begin
            if (x_pos >= MAX_X_POS) begin
                auto_next_x_pos = MAX_X_POS - 11'd1;
                auto_next_x_moving_right = 1'b0;
            end else begin
                auto_next_x_pos = x_pos + 11'd1;
            end
        end else if (x_pos == 0) begin
            auto_next_x_pos = 11'd1;
            auto_next_x_moving_right = 1'b1;
        end else begin
            auto_next_x_pos = x_pos - 11'd1;
        end

        if (y_moving_down) begin
            if (y_pos >= MAX_Y_POS) begin
                auto_next_y_pos = MAX_Y_POS - 11'd1;
                auto_next_y_moving_down = 1'b0;
            end else begin
                auto_next_y_pos = y_pos + 11'd1;
            end
        end else if (y_pos == 0) begin
            auto_next_y_pos = 11'd1;
            auto_next_y_moving_down = 1'b1;
        end else begin
            auto_next_y_pos = y_pos - 11'd1;
        end
    end

    // Apply the Lab 4 accelerometer step directly to the robust coordinate
    // model. Signed intermediate values prevent wraparound, and each axis is
    // clamped before framebuffer addresses are derived from the result.
    always @(*) begin
        accel_x_candidate = $signed({2'b0, x_pos})
                          + $signed({x_accel_scaled[11], x_accel_scaled});
        accel_y_candidate = $signed({2'b0, y_pos})
                          + $signed({y_accel_scaled[11], y_accel_scaled});

        accel_next_x_pos = x_pos;
        accel_next_y_pos = y_pos;
        accel_next_x_moving_right = x_moving_right;
        accel_next_y_moving_down = y_moving_down;
        accel_horizontal_collision = 1'b0;
        accel_vertical_collision = 1'b0;

        if (x_accel_scaled < 0) begin
            if (accel_x_candidate <= 0) begin
                accel_next_x_pos = 11'd0;
                accel_next_x_moving_right = 1'b1;
                accel_horizontal_collision = 1'b1;
            end else begin
                accel_next_x_pos = accel_x_candidate[10:0];
                accel_next_x_moving_right = 1'b0;
            end
        end else if (x_accel_scaled > 0) begin
            if (accel_x_candidate >= $signed({2'b0, MAX_X_POS})) begin
                accel_next_x_pos = MAX_X_POS;
                accel_next_x_moving_right = 1'b0;
                accel_horizontal_collision = 1'b1;
            end else begin
                accel_next_x_pos = accel_x_candidate[10:0];
                accel_next_x_moving_right = 1'b1;
            end
        end

        if (y_accel_scaled < 0) begin
            if (accel_y_candidate <= 0) begin
                accel_next_y_pos = 11'd0;
                accel_next_y_moving_down = 1'b1;
                accel_vertical_collision = 1'b1;
            end else begin
                accel_next_y_pos = accel_y_candidate[10:0];
                accel_next_y_moving_down = 1'b0;
            end
        end else if (y_accel_scaled > 0) begin
            if (accel_y_candidate >= $signed({2'b0, MAX_Y_POS})) begin
                accel_next_y_pos = MAX_Y_POS;
                accel_next_y_moving_down = 1'b0;
                accel_vertical_collision = 1'b1;
            end else begin
                accel_next_y_pos = accel_y_candidate[10:0];
                accel_next_y_moving_down = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            frame_counter <= 2'b0;
        end else if (frame_end) begin
            if (frame_counter == FRAME_INTERVAL) begin
                frame_counter <= 2'b0;
            end else begin
                frame_counter <= frame_counter + 2'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            color <= 3'b001;
        end else if (animation_tick && movement_collision) begin
            if (color == 3'b111) begin
                color <= 3'b001;
            end else begin
                color <= color + 3'b001;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            start_pos <= START_POS;
            end_pos <= END_POS;
            x_pos <= X_POS;
            y_pos <= Y_POS;
            x_moving_right <= 1'b1;
            y_moving_down <= 1'b1;
        end else if (animation_tick) begin
            // Acceleration mode has the same priority it had in Lab 4.
            if (accel_mode) begin
                x_pos <= accel_next_x_pos;
                y_pos <= accel_next_y_pos;
                x_moving_right <= accel_next_x_moving_right;
                y_moving_down <= accel_next_y_moving_down;
                start_pos <= accel_next_y_pos * ROW_STRIDE
                           + {9'd0, accel_next_x_pos};
                end_pos <= accel_next_y_pos * ROW_STRIDE
                         + {9'd0, accel_next_x_pos} + SPRITE_SPAN;
            end else if (!edit_mode) begin
                x_pos <= auto_next_x_pos;
                y_pos <= auto_next_y_pos;
                x_moving_right <= auto_next_x_moving_right;
                y_moving_down <= auto_next_y_moving_down;
                start_pos <= auto_next_y_pos * ROW_STRIDE
                           + {9'd0, auto_next_x_pos};
                end_pos <= auto_next_y_pos * ROW_STRIDE
                         + {9'd0, auto_next_x_pos} + SPRITE_SPAN;
            end else if (up_ctrl && y_pos > 0) begin
                start_pos <= start_pos - ROW_STRIDE;
                end_pos <= end_pos - ROW_STRIDE;
                y_pos <= y_pos - 11'd1;
            end else if (down_ctrl && y_pos < MAX_Y_POS) begin
                start_pos <= start_pos + ROW_STRIDE;
                end_pos <= end_pos + ROW_STRIDE;
                y_pos <= y_pos + 11'd1;
            end else if (left_ctrl && x_pos > 0) begin
                start_pos <= start_pos - 20'd1;
                end_pos <= end_pos - 20'd1;
                x_pos <= x_pos - 11'd1;
            end else if (right_ctrl && x_pos < MAX_X_POS) begin
                start_pos <= start_pos + 20'd1;
                end_pos <= end_pos + 20'd1;
                x_pos <= x_pos + 11'd1;
            end
        end
    end
endmodule
