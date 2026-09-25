/*
This module calculates the running average of 12-bit signed binary values 
(x_binary, y_binary, z_binary) and 19-bit signed binary values (t_binary). 
It accumulates the values over 64 clock cycles and outputs the average 
when the cycle is complete.

Inputs:
  - clk: System clock input.
  - reset: Asynchronous reset signal, active high.
  - x_binary, y_binary, z_binary: 12-bit signed binary input values for averaging.
  - t_binary: 19-bit signed binary input value for averaging.
  - copy_values: Enables the accumulation of new values.

Outputs:
  - x_avg, y_avg, z_avg: 12-bit signed averages of the accumulated x, y, and z values.
  - t_avg: 19-bit signed average of the accumulated t values.
  - ready: Indicates that the averages are available and valid.

Functionality:
  1. Accumulates the input values (`x_binary`, `y_binary`, `z_binary`, `t_binary`)
     over 64 clock cycles if `copy_values` is asserted.
  2. Outputs the calculated averages (`x_avg`, `y_avg`, `z_avg`, `t_avg`) after 
     64 clock cycles and asserts the `ready` signal.

Internal Signals:
  - `partial_sum_x`, `partial_sum_y`, `partial_sum_z`, `partial_sum_t`: 
    Registers to hold the accumulated sums.
  - `partial_sum_count`: A 6-bit counter to track the number of accumulated values.
*/
module avg_calc (
    clk,
    reset,
    x_binary,
    y_binary,
    z_binary,
    t_binary,
    x_avg,
    y_avg,
    z_avg,
    t_avg,
    copy_values,
    ready
);
    /* Inputs/Outputs */
    input clk, reset, copy_values;
    input signed [11:0] x_binary, y_binary, z_binary;
    input signed [18:0] t_binary;
    output reg signed [11:0] x_avg, y_avg, z_avg;
    output reg signed [18:0] t_avg;
    output reg ready;

    /* Internal signals */
    reg signed [17:0] partial_sum_x, partial_sum_y, partial_sum_z;
    reg signed [24:0] partial_sum_t;
    reg [5:0] partial_sum_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            partial_sum_x <= 18'd0;
            partial_sum_y <= 18'd0;
            partial_sum_z <= 18'd0;
            partial_sum_t <= 25'd0;
        end else if (copy_values) begin
            if (partial_sum_count == 6'd0) begin
                partial_sum_x <= x_binary;
                partial_sum_y <= y_binary;
                partial_sum_z <= z_binary;
                partial_sum_t <= t_binary;
            end else begin
                partial_sum_x <= partial_sum_x + x_binary;
                partial_sum_y <= partial_sum_y + y_binary;
                partial_sum_z <= partial_sum_z + z_binary;
                partial_sum_t <= partial_sum_t + t_binary;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            partial_sum_count <= 7'd0;
        end else if (copy_values) begin
            partial_sum_count <= partial_sum_count + 7'b1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ready <= 1'b0;
        end else if (copy_values && partial_sum_count == 6'd63) begin
            ready <= 1'b1;
        end else begin
            ready <= 1'b0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            x_avg <= 12'd0;
            y_avg <= 12'd0;
            z_avg <= 12'd0;
            t_avg <= 19'd0;
        end else if (copy_values && partial_sum_count == 6'd63) begin
            x_avg <= (partial_sum_x + x_binary) >>> 3'd6;
            y_avg <= (partial_sum_y + y_binary) >>> 3'd6;
            z_avg <= (partial_sum_z + z_binary) >>> 3'd6;
            t_avg <= (partial_sum_t + t_binary) >>> 3'd6;
        end
    end
    
endmodule