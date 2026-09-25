`timescale 1ns/1ps

module tb_sprite_controller_accel;
    localparam integer X_BOUNDARY = 127;
    localparam integer Y_BOUNDARY = 95;
    localparam integer WIDTH = 51;
    localparam integer HEIGHT = 23;
    localparam integer MAX_X = X_BOUNDARY - WIDTH + 1;
    localparam integer MAX_Y = Y_BOUNDARY - HEIGHT + 1;
    localparam integer ROW_STRIDE = X_BOUNDARY + 1;
    localparam integer SPRITE_SPAN = (HEIGHT - 1) * ROW_STRIDE + WIDTH - 1;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg frame_end = 1'b0;
    reg edit_mode = 1'b0;
    reg accel_mode = 1'b0;
    reg up_ctrl = 1'b0;
    reg down_ctrl = 1'b0;
    reg left_ctrl = 1'b0;
    reg right_ctrl = 1'b0;
    reg signed [11:0] x_accel = 12'sd0;
    reg signed [11:0] y_accel = 12'sd0;
    wire [13:0] start_pos;
    wire [13:0] end_pos;
    wire r, g, b;
    integer errors = 0;
    reg [2:0] color_before;

    always #5 clk = ~clk;

    sprite_controller #(.X_POS(7'd10), .Y_POS(7'd10)) dut (
        .clk(clk), .reset(reset), .edit_mode(edit_mode), .accel_mode(accel_mode),
        .up_ctrl(up_ctrl), .down_ctrl(down_ctrl), .left_ctrl(left_ctrl), .right_ctrl(right_ctrl),
        .x_accel(x_accel), .y_accel(y_accel), .frame_end(frame_end),
        .start_pos(start_pos), .end_pos(end_pos), .r(r), .g(g), .b(b)
    );

    task frame_pulse;
        begin
            frame_end = 1'b1;
            @(posedge clk); #1;
            frame_end = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    task animation_update;
        begin
            frame_pulse;
            frame_pulse;
            frame_pulse;
        end
    endtask

    task set_position;
        input [6:0] x;
        input [6:0] y;
        begin
            dut.x_pos = x;
            dut.y_pos = y;
            dut.start_pos = y * ROW_STRIDE + x;
            dut.end_pos = y * ROW_STRIDE + x + SPRITE_SPAN;
        end
    endtask

    task check_position;
        input [6:0] expected_x;
        input [6:0] expected_y;
        begin
            if (dut.x_pos !== expected_x || dut.y_pos !== expected_y) begin
                $display("FAIL position: got (%0d,%0d), expected (%0d,%0d)",
                         dut.x_pos, dut.y_pos, expected_x, expected_y);
                errors = errors + 1;
            end
            if (start_pos !== expected_y * ROW_STRIDE + expected_x) begin
                $display("FAIL start address: got %0d expected %0d", start_pos,
                         expected_y * ROW_STRIDE + expected_x);
                errors = errors + 1;
            end
            if (end_pos !== start_pos + SPRITE_SPAN) begin
                $display("FAIL end address: start=%0d end=%0d", start_pos, end_pos);
                errors = errors + 1;
            end
            if (dut.x_pos > MAX_X || dut.y_pos > MAX_Y) begin
                $display("FAIL bounds: (%0d,%0d)", dut.x_pos, dut.y_pos);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        #1 reset = 1'b0;

        // Lab 4 scaling: signed accelerometer values are divided by 256.
        accel_mode = 1'b1;
        x_accel = 12'sd768;   // +3 pixels
        y_accel = -12'sd512;  // -2 pixels
        animation_update;
        check_position(7'd13, 7'd8);

        // Zero acceleration holds the sprite in place.
        x_accel = 12'sd0;
        y_accel = 12'sd0;
        animation_update;
        check_position(7'd13, 7'd8);

        // Preserve Lab 4 mode priority: acceleration overrides edit controls.
        edit_mode = 1'b1;
        x_accel = 12'sd256;
        animation_update;
        check_position(7'd14, 7'd8);
        edit_mode = 1'b0;

        // Overshoot is clamped to the complete 51x23 sprite boundary.
        set_position(7'd76, 7'd72);
        dut.x_moving_right = 1'b1;
        dut.y_moving_down = 1'b1;
        color_before = dut.color;
        x_accel = 12'sd768;
        y_accel = 12'sd768;
        animation_update;
        check_position(MAX_X, MAX_Y);
        if (dut.color !== color_before + 3'b001) begin
            $display("FAIL collision color at bottom-right: before=%b after=%b", color_before, dut.color);
            errors = errors + 1;
        end

        // Reaching the top-left exactly is also a collision, as in Lab 4.
        set_position(7'd2, 7'd2);
        color_before = dut.color;
        x_accel = -12'sd512;
        y_accel = -12'sd512;
        animation_update;
        check_position(7'd0, 7'd0);
        if (dut.color !== color_before + 3'b001) begin
            $display("FAIL collision color at top-left: before=%b after=%b", color_before, dut.color);
            errors = errors + 1;
        end

        // An outward accelerometer collision leaves auto mode pointing inward.
        set_position(MAX_X, MAX_Y);
        x_accel = 12'sd768;
        y_accel = 12'sd768;
        animation_update;
        accel_mode = 1'b0;
        color_before = dut.color;
        animation_update;
        check_position(MAX_X - 1, MAX_Y - 1);
        if (dut.color !== color_before) begin
            $display("FAIL mode transition caused a duplicate collision color change");
            errors = errors + 1;
        end

        // Existing edit-mode movement and address stride remain intact.
        edit_mode = 1'b1;
        set_position(7'd5, 7'd5);
        up_ctrl = 1'b1;
        animation_update;
        up_ctrl = 1'b0;
        check_position(7'd5, 7'd4);

        // Long-running automatic motion must retain all bounds/address invariants.
        edit_mode = 1'b0;
        repeat (250) begin
            animation_update;
            check_position(dut.x_pos, dut.y_pos);
        end

        if (errors == 0) begin
            $display("PASS: accelerometer, collision, auto, and edit behavior");
            $finish;
        end
        $fatal(1, "sprite controller integration failures: %0d", errors);
    end
endmodule
