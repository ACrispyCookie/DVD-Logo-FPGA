/*
This module converts a 12-bit signed binary number into its 
4-digit ASCII decimal representation, along with an indicator 
for whether the input number is negative.

Inputs:
  - clk: Clock signal.
  - reset: Asynchronous reset signal.
  - binary: 12-bit signed binary input number (2's complement representation).
  - start: Start signal to initiate the conversion process.

Outputs:
  - ascii_1, ascii_2, ascii_3, ascii_4: 8-bit ASCII codes for the decimal digits
    representing the binary input. ascii_1 corresponds to the most significant 
    digit, while ascii_4 corresponds to the least significant digit.
  - is_negative: Indicates whether the input number is negative.
  - ready: High when the module has completed the conversion process and the 
    ASCII outputs are valid.

Functionality:
  1. The module uses a Finite State Machine (FSM) with six states:
     - IDLE: Waits for the start signal.
     - WAIT_FOR_NEW: Waits if the last conversion was completed less than 
       WAIT_FOR_NEW_CYCLES cycles ago.
     - COPY: Copies the binary input to a register, determines the sign and resets internal registers.
     - SHIFT: Performs the binary-to-BCD conversion by left-shifting the binary
       input and accumulating results in BCD registers.
     - ADD: Adjusts BCD digits according to the Double Dabble algorithm.
     - READY: Signals the completion of the conversion process.
  2. The conversion process uses the Double Dabble algorithm to efficiently
     convert the binary input into its decimal representation in BCD format.
  3. Outputs are converted from BCD to ASCII by adding the ASCII offset for
     the digit '0' (48 in decimal).

Internal Signals:
  - current_state, next_state: Registers to manage the current and next FSM states.
  - bcd_1, bcd_2, bcd_3, bcd_4: Registers to store the 4-digit Binary-Coded Decimal (BCD) representation.
  - binary_reg: Register to store the absolute value of the binary input for processing.
  - shift_counter: Counter to track the number of shifts during the binary-to-BCD conversion.
  - wait_counter: Counter to implement the delay between consecutive conversions.
  - shift_enabled, adding_enabled, copy_binary, wait_for_new: Control signals for FSM operation.

Parameters:
  - BINARY_WIDTH: Width of the binary input (default: 12 bits).
  - ZERO_ASCII: ASCII value of the digit '0' (default: 48).
  - WAIT_FOR_NEW_CYCLES: Number of cycles to wait before a new conversion starts.
*/
module binary_to_ascii_4 (
    clk,
    reset,
    binary,
    start,
    ascii_1,
    ascii_2,
    ascii_3,
    ascii_4,
    is_negative,
    ready
);

    /* Parameters */
    localparam BINARY_WIDTH = 12;
    localparam ZERO_ASCII = 8'd48;
    localparam WAIT_FOR_NEW_CYCLES = 3'd4;
    
    /* FSM states */
    localparam IDLE = 3'd0;
    localparam WAIT_FOR_NEW = 3'd1;
    localparam COPY = 3'd2;
    localparam SHIFT = 3'd3;
    localparam ADD = 3'd4;
    localparam READY = 3'd5;

    /* Inputs/Outputs */
    input clk, reset;
    input [BINARY_WIDTH-1:0] binary;
    input start;
    output wire [7:0] ascii_1, ascii_2, ascii_3, ascii_4;
    output reg ready, is_negative;

    /* Internal signals */
    reg [3:0] bcd_1, bcd_2, bcd_3, bcd_4;
    reg [2:0] current_state, next_state;
    reg [3:0] shift_counter;
    reg [2:0] wait_counter;
    reg [BINARY_WIDTH-2:0] binary_reg;
    reg shift_enabled, adding_enabled, copy_binary, wait_for_new;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wait_counter <= 3'b0;
        end else if (wait_for_new && wait_counter != WAIT_FOR_NEW_CYCLES) begin
            wait_counter <= wait_counter + 3'b1;
        end else if (copy_binary) begin
            wait_counter <= 3'b0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            binary_reg <= 14'd0;
            is_negative <= 1'b0;
        end else if (copy_binary) begin
            binary_reg <= binary[BINARY_WIDTH-1] ? ~binary[BINARY_WIDTH-2:0] + 1 : binary[BINARY_WIDTH-2:0];
            is_negative <= binary[BINARY_WIDTH-1];
        end else if (shift_enabled) begin
            binary_reg <= binary_reg << 1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bcd_1 <= 4'd0;
            bcd_2 <= 4'd0;
            bcd_3 <= 4'd0;
            bcd_4 <= 4'd0;
        end else if (copy_binary) begin
            bcd_1 <= 4'd0;
            bcd_2 <= 4'd0;
            bcd_3 <= 4'd0;
            bcd_4 <= 4'd0;
        end else if (adding_enabled) begin
            bcd_1 <= bcd_1 >= 5 ? bcd_1 + 4'd3 : bcd_1;
            bcd_2 <= bcd_2 >= 5 ? bcd_2 + 4'd3 : bcd_2;
            bcd_3 <= bcd_3 >= 5 ? bcd_3 + 4'd3 : bcd_3;
            bcd_4 <= bcd_4 >= 5 ? bcd_4 + 4'd3 : bcd_4;
        end else if (shift_enabled) begin
            {bcd_1, bcd_2, bcd_3, bcd_4} <= {bcd_1, bcd_2, bcd_3, bcd_4} << 1 | binary_reg[BINARY_WIDTH-2];
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            shift_counter <= 4'd0;
        end else if (shift_enabled) begin
            shift_counter <= shift_counter + 4'b1;
        end else if (copy_binary) begin
            shift_counter <= 4'd0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state; 
    end

    always @(current_state or start or shift_counter or wait_counter) begin
        case (current_state)
            IDLE: next_state = start ? WAIT_FOR_NEW : IDLE;
            WAIT_FOR_NEW: next_state = (wait_counter == WAIT_FOR_NEW_CYCLES) ? COPY : WAIT_FOR_NEW;
            COPY: next_state = SHIFT;
            SHIFT: next_state = (shift_counter == BINARY_WIDTH-2) ? READY : ADD;
            ADD: next_state = SHIFT;
            READY: next_state = IDLE; 
            default: next_state = IDLE;
        endcase
    end

    always @(current_state) begin
        case (current_state)
            IDLE: begin
                copy_binary = 1'b0;
                shift_enabled = 1'b0;
                adding_enabled = 1'b0;
                wait_for_new = 1'b1;
                ready = 1'b0;
            end
            WAIT_FOR_NEW: begin
                copy_binary = 1'b0;
                shift_enabled = 1'b0;
                adding_enabled = 1'b0;
                wait_for_new = 1'b1;
                ready = 1'b0;
            end
            COPY: begin
                copy_binary = 1'b1;
                shift_enabled = 1'b0;
                adding_enabled = 1'b0;
                wait_for_new = 1'b0;
                ready = 1'b0;
            end
            SHIFT: begin
                copy_binary = 1'b0;
                shift_enabled = 1'b1;
                adding_enabled = 1'b0;
                wait_for_new = 1'b0;
                ready = 1'b0;
            end
            ADD: begin
                copy_binary = 1'b0;
                shift_enabled = 1'b0;
                adding_enabled = 1'b1;
                wait_for_new = 1'b0;
                ready = 1'b0;
            end
            READY: begin
                copy_binary = 1'b0;
                shift_enabled = 1'b0;
                adding_enabled = 1'b0;
                wait_for_new = 1'b0;
                ready = 1'b1;
            end
            default: begin
                copy_binary = 1'b0;
                shift_enabled = 1'b0;
                adding_enabled = 1'b0;
                wait_for_new = 1'b0;
                ready = 1'b0;
            end
        endcase
    end

    assign ascii_1 = bcd_1 + ZERO_ASCII;
    assign ascii_2 = bcd_2 + ZERO_ASCII;
    assign ascii_3 = bcd_3 + ZERO_ASCII;
    assign ascii_4 = bcd_4 + ZERO_ASCII;    

endmodule