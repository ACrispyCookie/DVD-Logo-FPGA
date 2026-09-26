`timescale 1ns/1ps

module tb_accelerometer_spi_path;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg send = 1'b0;
    reg miso = 1'b0;
    reg [7:0] command = 8'h0A;
    reg [7:0] address = 8'h1F;
    reg [7:0] data = 8'h52;
    wire spi_enable, spi_ready, ss, sclk, mosi, command_done;
    wire [7:0] spi_transmit_data, received_data;

    integer edge_count = 0;
    integer byte_count = 0;
    integer timeout = 0;
    reg [7:0] captured = 8'd0;
    reg [7:0] bytes [0:2];

    always #10 clk = ~clk; // 50 MHz

    command_sender sender(
        .clk(clk), .reset(reset), .spi_enable(spi_enable), .spi_ready(spi_ready),
        .spi_ss(ss), .spi_transmit_data(spi_transmit_data), .send(send),
        .command_done(command_done), .command(command), .address(address), .data(data)
    );

    spi_master master(
        .clk(clk), .reset(reset), .sclk(sclk), .ss(ss), .mosi(mosi), .miso(miso),
        .enable(spi_enable), .data_ready(spi_ready),
        .data_to_transmit(spi_transmit_data), .received_data(received_data)
    );

    always @(posedge sclk) begin
        if (!ss) begin
            captured = {captured[6:0], mosi};
            edge_count = edge_count + 1;
            if ((edge_count % 8) == 0) begin
                if (byte_count < 3)
                    bytes[byte_count] = captured;
                byte_count = byte_count + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (command_done)
            send <= 1'b0;
    end

    initial begin
        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (4) @(posedge clk);
        send = 1'b1;

        while ((byte_count < 3 || !ss) && timeout < 3000) begin
            @(posedge clk); #1;
            timeout = timeout + 1;
        end

        if (timeout == 3000)
            $fatal(1, "SPI command sequence did not finish");
        if (edge_count != 24)
            $fatal(1, "SPI command used %0d selected rising edges, expected 24", edge_count);
        if (bytes[0] !== command || bytes[1] !== address || bytes[2] !== data)
            $fatal(1, "SPI bytes were %02h %02h %02h, expected %02h %02h %02h",
                   bytes[0], bytes[1], bytes[2], command, address, data);

        $display("PASS: command sender emits exactly three correctly framed SPI bytes");
        $finish;
    end
endmodule
