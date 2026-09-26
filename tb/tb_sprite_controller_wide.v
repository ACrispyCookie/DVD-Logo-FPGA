`timescale 1ns/1ps

module tb_sprite_controller_wide;
    localparam [10:0] X_BOUNDARY = 11'd1279;
    localparam [10:0] Y_BOUNDARY = 11'd719;
    localparam [10:0] X_START = 11'd1024;
    localparam [10:0] Y_START = 11'd600;
    localparam [19:0] ROW_STRIDE = 20'd1280;
    localparam [19:0] SPRITE_SPAN = 20'd28210;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg frame_end = 1'b0;
    reg accel_mode = 1'b1;
    reg signed [11:0] x_accel = 12'sd256;
    reg signed [11:0] y_accel = 12'sd256;
    wire [19:0] start_pos, end_pos;
    wire [10:0] sprite_x, sprite_y;
    wire r, g, b;

    always #5 clk = ~clk;

    sprite_controller #(
        .X_BOUNDARY(X_BOUNDARY), .Y_BOUNDARY(Y_BOUNDARY),
        .X_POS(X_START), .Y_POS(Y_START)
    ) dut (
        .clk(clk), .reset(reset), .edit_mode(1'b0),
        .accel_mode(accel_mode), .x_accel(x_accel), .y_accel(y_accel),
        .up_ctrl(1'b0), .down_ctrl(1'b0),
        .left_ctrl(1'b0), .right_ctrl(1'b0), .frame_end(frame_end),
        .start_pos(start_pos), .end_pos(end_pos),
        .sprite_x(sprite_x), .sprite_y(sprite_y), .r(r), .g(g), .b(b)
    );

    task frame_pulse;
        begin
            frame_end = 1'b1;
            @(posedge clk); #1;
            frame_end = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        if (sprite_x !== X_START || sprite_y !== Y_START)
            $fatal(1, "wide initial position was truncated: x=%0d y=%0d", sprite_x, sprite_y);
        if (start_pos !== (Y_START * ROW_STRIDE + X_START))
            $fatal(1, "wide initial framebuffer address was incorrect: %0d", start_pos);

        frame_pulse;
        frame_pulse;
        frame_pulse;
        if (sprite_x !== 11'd1025 || sprite_y !== 11'd601)
            $fatal(1, "wide acceleration movement was truncated: x=%0d y=%0d", sprite_x, sprite_y);
        if (start_pos !== (20'd601 * ROW_STRIDE + 20'd1025))
            $fatal(1, "wide moved framebuffer address was incorrect: %0d", start_pos);
        if (end_pos !== start_pos + SPRITE_SPAN)
            $fatal(1, "wide sprite span invariant failed");

        $display("PASS: 720p-width sprite coordinates and addresses do not truncate");
        $finish;
    end
endmodule
