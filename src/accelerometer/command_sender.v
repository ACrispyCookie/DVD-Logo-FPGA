/*
This module acts as a controller for sending SPI commands, addresses, and 
data to a slave device. It coordinates the data transmission process through
the SPI interface by managing the enable signal, selecting the appropriate 
data to send, and monitoring the readiness of the SPI interface. It follows 
a finite state machine (FSM) to ensure the correct sequence of operations.

Inputs:
  - clk: System clock input.
  - reset: Asynchronous reset signal, active high.
  - send: Signal to control the transmission sequence:
           - In burst mode, `send` remains high to send multiple data bytes.
           - In single mode, `send` is deasserted to end communication after 
             one command, address, and data byte.
  - spi_ready: Indicates when the SPI interface is ready for the next data byte.
  - spi_ss: Slave select signal from the SPI interface (active low).
  - command: 8-bit command byte to be sent first.
  - address: 8-bit address byte to be sent second.
  - data: 8-bit data byte to be sent third.

Outputs:
  - spi_enable: Control signal to enable SPI transmission.
  - spi_transmit_data: 8-bit data to be sent through the SPI interface.
  - command_done: Indicates that the entire command sequence or the current
                  data byte has been successfully sent. 
                  - In burst mode, if `send` remains high, the next data byte is 
                    sent immediately.
                  - In single mode, if `send` goes low, the communication ends 
                    and a new command can be initiated.

FSM States:
  - IDLE: Waits for the `send` signal to initiate a command sequence.
  - SEND_COMMAND: Sends the command byte over the SPI interface.
  - SEND_ADDRESS: Sends the address byte over the SPI interface.
  - SEND_DATA: Sends the data byte over the SPI interface.
  - COMPLETED: Marks the completion of the command sequence.
  - COMMAND_END: Waits for the slave select signal to deassert before resetting.

Parameters:
  - COMMAND: Transmit select value for the command byte.
  - ADDRESS: Transmit select value for the address byte.
  - DATA: Transmit select value for the data byte.

Internal Signals:
  - current_state: The current state of the FSM.
  - next_state: The next state of the FSM, determined by inputs and current state.
  - transmit_select: Determines the type of data to send (command, address, or data).

Functionality:
  1. **Single Mode Operation**:
     - The `send` signal is asserted high to initiate a command sequence.
     - The command, address, and a single data byte are transmitted sequentially.
     - When `command_done` becomes high after sending the data byte, the module 
       waits for `send` to deassert, completing the communication.
  2. **Burst Mode Operation**:
     - The `send` signal is held high during and after the initial command, address,
       and data transmission.
     - When `command_done` becomes high, the next data byte is transmitted 
       immediately, allowing for continuous data transfer without interruption.
     - The communication ends when `send` is deasserted.
  3. Coordinates with an SPI Master module to ensure data is sent only when 
     the SPI interface is ready.
  4. Provides the `command_done` signal to indicate when the module is ready for 
     the next data byte or to complete communication.
*/
module command_sender (
    clk,
    reset,
    spi_enable,
    spi_ready,
    spi_ss,
    spi_transmit_data,
    send,
    command_done,
    command,
    address,
    data
);

    /* Transmit select values */
    parameter COMMAND = 2'd1;
    parameter ADDRESS = 2'd2;
    parameter DATA = 2'd3;

    /* FSM states */
    parameter IDLE = 3'd0;
    parameter SEND_COMMAND = 3'd1;
    parameter SEND_ADDRESS = 3'd2;
    parameter SEND_DATA = 3'd3;
    parameter COMPLETED = 3'd4;
    parameter COMMAND_END = 3'd5;

    /* Inputs/Outputs */
    input clk, reset;
    input send, spi_ready, spi_ss;
    input [7:0] command, address, data;
    output reg [7:0] spi_transmit_data;
    output wire command_done;

    /* FSMs signals */
    output reg spi_enable;
    reg [2:0] current_state, next_state;
    reg [1:0] transmit_select;

    assign command_done = transmit_select == DATA && spi_ready;

    always @(transmit_select or command or address or data) begin
        case (transmit_select)
            COMMAND: spi_transmit_data = command;
            ADDRESS: spi_transmit_data = address;
            DATA: spi_transmit_data = data;
            default: spi_transmit_data = data;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(current_state or send or spi_ready or spi_ss) begin
        case (current_state)
            IDLE: next_state = send ? SEND_COMMAND : IDLE;
            SEND_COMMAND: next_state = spi_ready ? SEND_ADDRESS : SEND_COMMAND;
            SEND_ADDRESS: next_state = spi_ready ? SEND_DATA : SEND_ADDRESS;
            SEND_DATA: next_state = spi_ready ? COMPLETED : SEND_DATA;
            COMPLETED: next_state = send ? SEND_DATA : COMMAND_END;
            COMMAND_END: next_state = spi_ss ? IDLE : COMMAND_END;
            default: next_state = IDLE;
        endcase
    end

    always @(current_state) begin
        case (current_state)
            IDLE: begin
                spi_enable = 1'b0;
                transmit_select = 2'd0;
            end
            SEND_COMMAND: begin
                spi_enable = 1'b1;
                transmit_select = COMMAND;
            end
            SEND_ADDRESS: begin
                spi_enable = 1'b1;
                transmit_select = ADDRESS;
            end
            SEND_DATA: begin
                spi_enable = 1'b1;
                transmit_select = DATA;
            end
            COMPLETED: begin
                spi_enable = 1'b0;
                transmit_select = 2'd0;
            end
            COMMAND_END: begin
                spi_enable = 1'b0;
                transmit_select = 2'd0;
            end
            default: begin
                spi_enable = 1'b0;
                transmit_select = 2'd0;
            end
        endcase
    end
    
endmodule