`timescale 1ns/1ps

// Module: baud_controller                                                                                    //
//                                                                                                            //
// DESCRIPTION:                                                                                               //
// This module implements the baud rate controller for a UART (Universal Asynchronous Receiver/Transmitter).  //
// The baud rate controller is responsible for generating the clock enable signal at the desired baud rate    //
// for the UART communication. It divides the input clock frequency to match the required baud rate, ensuring //
// accurate timing for data transmission and reception.                                                       //

module Baud_controller (reset, clk, baud_select, sample_ENABLE);
input reset, clk;
input [2:0] baud_select;
output reg sample_ENABLE;

reg [14:0] counter;
reg [14:0] limit;
reg counter_reset;

// 16x oversampling limits for the board's 50 MHz input clock. Limits are
// one less than the cycle count because the counter starts at zero.
always @(*)
begin
    case (baud_select) 
        3'b000: limit = 10416; // 300 baud
        3'b001: limit = 2603;  // 1,200 baud
        3'b010: limit = 650;   // 4,800 baud
        3'b011: limit = 325;   // 9,600 baud
        3'b100: limit = 162;   // 19,200 baud
        3'b101: limit = 80;    // 38,400 baud
        3'b110: limit = 53;    // 57,600 baud
        3'b111: limit = 26;    // 115,200 baud
        default: limit = 53;
    endcase 
end

always @(posedge clk or posedge reset)
begin
    if(reset)
        counter <= 0;
    else
        if(counter_reset == 1)
            counter <= counter + 15'b1; 
        else
            counter <= 0;
end

always @(counter or limit)
begin
    if(counter == limit)
    begin
        sample_ENABLE = 1;
        counter_reset = 0;
    end
    else
    begin
        sample_ENABLE = 0;
        counter_reset = 1;
    end

end



endmodule
