/*
This module acts as a controller for reading sensor data and calculating 
averages over time. It coordinates with the `command_sender` module to send 
SPI commands, addresses, and data to the sensor, and handles the reception of 
raw sensor data for processing. The module uses a finite state machine (FSM) 
to manage the sequence of operations, including sensor initialization, data 
reading, and averaging of the collected values.

Inputs:
  - clk: System clock input.
  - reset: Asynchronous reset signal, active high.
  - command_done: Indicates when the `command_sender` module has completed 
    sending the current command or data byte.
  - received_data: 8-bit data received from the sensor via the `command_sender` 
    module during the data reading process.
  - values_ready: Indicates when the averaged sensor values are ready for use.
  - x_avg, y_avg, z_avg: 12-bit output values representing the average of the 
    sensor data for X, Y, and Z axes.
  - t_avg: 18-bit output value representing the averaged temperature data.

Outputs:
  - send: Control signal to initiate the transmission of commands and data 
    through the `command_sender` module.
  - command: 8-bit command byte to be sent first via the `command_sender` module.
  - address: 8-bit address byte to be sent second via the `command_sender` module.
  - data: 8-bit data byte to be sent third via the `command_sender` module.
  - x_raw, y_raw, z_raw, t_raw: 12-bit signed raw sensor data for X, Y, Z, and 
    temperature readings.

FSM States:
  - RESET: Resets the sensor and prepares for data collection.
  - WAIT_RESET: Waits for the sensor reset process to complete.
  - FILTER_CONTROL: Configures filtering settings on the sensor.
  - POWER_CONTROL: Configures power control settings on the sensor.
  - INIT_DONE: Marks the completion of sensor initialization.
  - READ: Reads the raw data from the sensor (X, Y, Z, T).
  - COPY_TO_AVG: Sends the collected raw data to the averaging module.
  - READ_DONE: Marks the completion of the data reading and waits for the next reading to start.

Parameters:
  - RESET_WAIT_TIME: Time period to wait for the sensor reset to complete.
  - READ_WAIT_TIME: Time period to wait after reading the data before the next operation.

Internal Signals:
  - current_state: The current state of the FSM.
  - next_state: The next state of the FSM, determined by inputs and current state.
  - wait_counter: A counter to keep track of the wait time for reset and read operations.
  - read_counter: A counter to track the read stages for X, Y, Z, and temperature data.
  - add_to_avg: Signal that copies the read data to the average calculator.

Functionality:
  1. **Sensor Data Reading**:
     - The module coordinates with the `command_sender` module to send commands 
       to the sensor to configure its settings (e.g., filter and power control), 
       and then reads the raw data from the sensor in multiple stages (X, Y, Z, T).
     - The data is read sequentially with each byte received from the sensor, 
       using SPI communication handled by the `command_sender` module.
  2. **Averaging**:
     - Once the raw data is collected, it is passed to the `avg_calc` module 
       which computes the average values for X, Y, Z, and temperature.
     - The averaged values are outputted as `x_avg`, `y_avg`, `z_avg`, and `t_avg`.
  3. **FSM Operation**:
     - The FSM controls the state transitions, including resetting the sensor, 
       reading the sensor values, and copying them to the averaging module.
     - The module operates in a sequence from initialization to the completion of 
       the reading and averaging process.
  5. **Sensor Configuration**:
     - The module configures the sensor's filtering and power settings before 
       initiating data collection to ensure correct readings.
*/
module value_reader (
    clk,
    reset,
    x_avg,
    y_avg,
    z_avg,
    t_avg,
    values_ready,
    send,
    command_done,
    command,
    address,
    data,
    received_data
);

    /* Read counter values */
    localparam X_LOW = 3'd0;
    localparam X_HIGH = 3'd1;
    localparam Y_LOW = 3'd2;
    localparam Y_HIGH = 3'd3;
    localparam Z_LOW = 3'd4;
    localparam Z_HIGH = 3'd5;
    localparam T_LOW = 3'd6;
    localparam T_HIGH = 3'd7;

    /* Wait counter values */
    localparam RESET_WAIT_TIME = 19'd50000;
    localparam READ_WAIT_TIME = 19'd500000;

    /* FSM states */
    localparam RESET = 4'd0;
    localparam WAIT_RESET = 4'd1;
    localparam FILTER_CONTROL = 4'd2;
    localparam POWER_CONTROL = 4'd3;
    localparam INIT_DONE = 4'd4;
    localparam READ = 4'd5;
    localparam READ_DONE = 4'd6;
    localparam COPY_TO_AVG = 4'd7;
    localparam READ_WAIT = 4'd8;

    /* FSM signals */
    reg [3:0] current_state, next_state;
    reg [18:0] wait_counter;
    reg [2:0] read_counter;
    reg run_wait_counter, run_read_counter, add_to_avg;
    output reg send;
    output reg [7:0] command, address, data;

    /* Inputs/Outputs */
    input clk, reset;
    input command_done;
    input [7:0] received_data;
    output wire values_ready;

    /* Raw values */
    reg signed [11:0] x_raw, y_raw, z_raw, t_raw;

    /* Binary values */
    wire signed [11:0] x_binary, y_binary, z_binary;
    wire signed [18:0] t_binary;

    assign x_binary = x_raw;
    assign y_binary = y_raw;
    assign z_binary = z_raw;
    assign t_binary = (t_raw << 3'd6) + t_raw;

    /* Avg values */
    output wire signed [11:0] x_avg, y_avg, z_avg;
    output wire signed [18:0] t_avg;

    avg_calc avg_calc_inst(.clk(clk), .reset(reset), .x_binary(x_binary), .y_binary(y_binary), 
    .z_binary(z_binary), .t_binary(t_binary), .copy_values(add_to_avg), .x_avg(x_avg), .y_avg(y_avg), .z_avg(z_avg), .t_avg(t_avg),
    .ready(values_ready));

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            x_raw <= 12'b0;
        end else if (command_done) begin
            if (read_counter == X_LOW)
                x_raw[7:0] <= received_data;
            else if (read_counter == X_HIGH)
                x_raw[11:8] <= received_data[3:0];
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            y_raw <= 12'b0;
        end else if (command_done) begin
            if (read_counter == Y_LOW)
                y_raw[7:0] <= received_data;
            else if (read_counter == Y_HIGH)
                y_raw[11:8] <= received_data[3:0];
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            z_raw <= 12'b0;
        end else if (command_done) begin
            if (read_counter == Z_LOW)
                z_raw[7:0] <= received_data;
            else if (read_counter == Z_HIGH)
                z_raw[11:8] <= received_data[3:0];
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            t_raw <= 12'b0;
        end else if (command_done) begin
            if (read_counter == T_LOW)
                t_raw[7:0] <= received_data;
            else if (read_counter == T_HIGH)
                t_raw[11:8] <= received_data[3:0];
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wait_counter <= 19'b0;
        end else if (run_wait_counter) begin
            wait_counter <= wait_counter + 19'b1;
        end else begin
            wait_counter <= 19'b0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            read_counter <= 3'b0;
        end else if (run_read_counter && command_done) begin
            read_counter <= read_counter + 3'b1;
        end else if (~run_read_counter) begin
            read_counter <= 3'b0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= RESET;
        end else begin
            current_state <= next_state;
        end
    end

    always @(current_state or command_done or wait_counter or read_counter) begin
        case (current_state)
            RESET: next_state = command_done ? WAIT_RESET : RESET;
            WAIT_RESET: next_state = wait_counter == RESET_WAIT_TIME ? FILTER_CONTROL : WAIT_RESET;
            FILTER_CONTROL: next_state = command_done ? POWER_CONTROL : FILTER_CONTROL;
            POWER_CONTROL: next_state = command_done ? INIT_DONE : POWER_CONTROL;
            INIT_DONE: next_state = READ;
            READ: next_state = (command_done) ? READ_DONE : READ;
            READ_DONE: next_state = (read_counter == T_HIGH) ? COPY_TO_AVG : READ;
            COPY_TO_AVG: next_state = READ_WAIT;
            READ_WAIT: next_state = wait_counter == READ_WAIT_TIME ? READ : READ_WAIT;
            default: next_state = RESET;
        endcase
    end

    always @(current_state) begin
        case (current_state)
            RESET: begin
                send = 1'b1;
                run_wait_counter = 1'b0;
                run_read_counter = 1'b0;
                command = 8'h0a;
                address = 8'h1f;
                data = 8'h52;
                add_to_avg = 1'b0;
            end
            WAIT_RESET:  begin
                send = 1'b0;
                run_wait_counter = 1'b1;
                run_read_counter = 1'b0;
                command = 8'h0;
                address = 8'h0;
                data = 8'h0;
                add_to_avg = 1'b0;
            end
            FILTER_CONTROL:  begin
                send = 1'b1;
                run_wait_counter = 1'b0;
                run_read_counter = 1'b0;
                command = 8'h0a;
                address = 8'h2c;
                data = 8'b00_0_1_0_100;
                add_to_avg = 1'b0;
            end
            POWER_CONTROL:  begin
                send = 1'b1;
                run_wait_counter = 1'b0;
                run_read_counter = 1'b0;
                command = 8'h0;
                address = 8'h0;
                data = 8'b0_0_00_0_0_10;
                add_to_avg = 1'b0;
            end
            INIT_DONE:  begin
                send = 1'b0;
                run_wait_counter = 1'b0;
                run_read_counter = 1'b0;
                command = 8'h0;
                address = 8'h0;
                data = 8'h0;
                add_to_avg = 1'b0;
            end
            READ:  begin
                send = 1'b1;
                run_wait_counter = 1'b0;
                run_read_counter = 1'b1;
                command = 8'h0b;
                address = 8'h0e;
                data = 8'h0;
                add_to_avg = 1'b0;
            end
            READ_DONE:  begin
                send = 1'b0;
                run_wait_counter = 1'b0;
                run_read_counter = 1'b0;
                command = 8'h0;
                address = 8'h0;
                data = 8'h0;
                add_to_avg = 1'b0;
            end
            COPY_TO_AVG:  begin
                send = 1'b0;
                run_wait_counter = 1'b1;
                run_read_counter = 1'b0;
                command = 8'h0;
                address = 8'h0;
                data = 8'h0;
                add_to_avg = 1'b1;
            end
            READ_WAIT:  begin
                send = 1'b0;
                run_wait_counter = 1'b1;
                run_read_counter = 1'b0;
                command = 8'h0;
                address = 8'h0;
                data = 8'h0;
                add_to_avg = 1'b0;
            end
            default: begin
                send = 1'b0;
                run_wait_counter = 1'b0;
                run_read_counter = 1'b0;
                command = 8'h0;
                address = 8'h0;
                data = 8'h0;
                add_to_avg = 1'b0;
            end
        endcase
    end

endmodule