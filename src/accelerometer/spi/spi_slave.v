/* Simple SPI Slave module that receives data from the SPI master
   and transmits the same 4 bytes of data back to the master. */
module spi_slave (
    clk,
    reset,
    mosi,
    miso,
    ss,
    ready,
    received_data
);

/* Inputs/Outputs */
input clk, reset, ss;
output reg ready;
output reg [7:0] received_data;

/* Communication related */
output reg miso;
reg miso_reg;
input mosi;
reg [7:0] shift_register;
reg [2:0] bit_counter;

reg [7:0] transmit_data [3:0];
reg [1:0] transmit_counter;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        transmit_data[0] <= 8'b10101101;
        transmit_data[1] <= 8'b00011101;
        transmit_data[2] <= 8'b00011111;
        transmit_data[3] <= 8'b10011111;
        transmit_counter <= 2'b0;
    end else if (!ss && bit_counter == 3'd6) begin
        transmit_counter <= transmit_counter + 2'b1;
    end
end

always @(bit_counter or ss) begin
    if (!ss && bit_counter == 3'd0)
        ready = 1'b1;
    else
        ready = 1'b0;
end

always @(miso_reg or ss) begin
    if (ss) begin
        miso = 1'b0;
    end else begin
        miso = miso_reg;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        received_data <= 8'b0;
    end else if (!ss && bit_counter == 3'd7) begin
        received_data <= {shift_register[6:0], mosi};
    end
end

always @(negedge clk or posedge reset) begin
    if (reset) begin
        miso_reg <= 1'b0;
    end else begin
        miso_reg <= shift_register[7];
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        shift_register <= 8'b10101101;
    end else if (!ss) begin
        if (bit_counter == 3'd7)
            shift_register <= transmit_data[transmit_counter];
        else
            shift_register <= {shift_register[6:0], mosi};
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        bit_counter <= 3'd0;
    end else if (!ss) begin
        bit_counter <= bit_counter + 3'b1;
    end
end
    
endmodule