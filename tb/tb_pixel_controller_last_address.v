`timescale 1ns/1ps

module tb_pixel_controller_last_address;
    reg clk = 1'b0;
    reg reset = 1'b0;
    reg write_enable = 1'b0;
    reg [19:0] write_address = 20'd0;
    reg [2:0] write_data = 3'b0;
    reg hrgb_enabled = 1'b1;
    reg vrgb_enabled = 1'b1;
    reg [10:0] hpixel = 11'd1279;
    reg [0:0] hpixel_upscale_counter = 1'b0;
    reg [10:0] vpixel = 11'd719;
    wire [2:0] rgb;

    always #5 clk = ~clk;

    pixel_controller #(.UPSCALE_WIDTH(1)) dut (
        .clk(clk), .reset(reset),
        .write_enable(write_enable), .write_address(write_address),
        .write_data(write_data), .hrgb_enabled(hrgb_enabled),
        .vrgb_enabled(vrgb_enabled), .hpixel(hpixel),
        .hpixel_upscale_counter(hpixel_upscale_counter),
        .vpixel(vpixel), .rgb(rgb)
    );

    initial begin
        #1;
        if (dut.current_address !== 20'd921599)
            $fatal(1, "last 720p framebuffer address was %0d", dut.current_address);
        if (dut.vram_address !== 20'd921599)
            $fatal(1, "prefetch read escaped framebuffer: %0d", dut.vram_address);
        $display("PASS: final displayed pixel never prefetches beyond framebuffer");
        $finish;
    end
endmodule
