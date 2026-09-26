`timescale 1ns/1ps

module tb_uart_baud_50mhz;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [2:0] baud_select = 3'b000;
    wire sample_ENABLE;
    integer cycle_count = 0;
    integer first_pulse_cycle = -1;
    integer interval = 0;

    always #10 clk = ~clk; // 50 MHz

    Baud_controller dut(
        .reset(reset), .clk(clk), .baud_select(baud_select),
        .sample_ENABLE(sample_ENABLE)
    );

    always @(posedge clk) begin
        #1;
        if (!reset) begin
            cycle_count = cycle_count + 1;
            if (sample_ENABLE) begin
                if (first_pulse_cycle < 0) begin
                    first_pulse_cycle = cycle_count;
                end else begin
                    interval = cycle_count - first_pulse_cycle;
                    if (interval != 54)
                        $fatal(1, "57,600-baud sample interval is %0d clocks, expected 54", interval);
                    $display("PASS: UART 57,600-baud timing matches the 50 MHz board clock");
                    $finish;
                end
            end
            if (cycle_count > 300)
                $fatal(1, "UART sample-enable did not produce two pulses");
        end
    end

    initial begin
        #1 baud_select = 3'b110; // 57,600 baud
        repeat (3) @(posedge clk);
        #1 reset = 1'b0;
    end
endmodule
