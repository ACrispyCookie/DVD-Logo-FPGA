`timescale 1ns/1ps

module tb_framebuffer_resize;
    reg clk = 1'b0;
    reg reset = 1'b0;
    reg write_enable = 1'b0;
    reg [19:0] write_address = 20'd0;
    reg [2:0] write_data = 3'b0;
    reg [19:0] read_address = 20'd0;
    wire r, g, b;

    always #5 clk = ~clk;

    vram dut (
        .clk(clk), .reset(reset),
        .write_enable(write_enable), .write_address(write_address),
        .write_data(write_data), .read_address(read_address),
        .r(r), .g(g), .b(b)
    );

    task write_pixel;
        input [19:0] address;
        input [2:0] color;
        begin
            @(negedge clk);
            write_enable = 1'b1;
            write_address = address;
            write_data = color;
            @(negedge clk);
            write_enable = 1'b0;
        end
    endtask

    task expect_pixel;
        input [19:0] address;
        input [2:0] color;
        begin
            @(negedge clk);
            read_address = address;
            @(posedge clk);
            #1;
            if ({r, g, b} !== color)
                $fatal(1, "pixel %0d was %b, expected %b", address, {r,g,b}, color);
        end
    endtask

    initial begin
        // 1280x720 at 1x scaling must reach address 921599.
        write_pixel(20'd0, 3'b101);
        write_pixel(20'd921599, 3'b011);
        expect_pixel(20'd0, 3'b101);
        expect_pixel(20'd921599, 3'b011);
        $display("PASS: framebuffer resizes through the final 720p pixel");
        $finish;
    end
endmodule
