`timescale 1ns / 1ps

module top (
    input clk,            // 100 MHz clock
    input rst,
    output uart_tx,       // UART TX to PC
    inout scl,
    inout sda,
    output [3:0] debug_state
);

    // === I2C ADC Interface ===
    wire [15:0] adc_word;
    wire        adc_new;
    wire [3:0]  debug_state_wire;

    i2c_comms u_i2c (
        .clk(clk),
        .rst(rst),
        .scl(scl),
        .sda(sda),
        .data_out(adc_word),
        .new_data(adc_new),
        .debug_state(debug_state_wire)   
    );

    assign debug_state = debug_state_wire;

    // === Sync new_data into clk domain ===
    reg nd_sync0, nd_sync1;
    always @(posedge clk) begin
        nd_sync0 <= adc_new;
        nd_sync1 <= nd_sync0;
    end
    wire mic_valid = nd_sync0 & ~nd_sync1;
    wire signed [15:0] mic_sample = adc_word;

    // === UART Transmission (send raw 16-bit sample) ===
    wire uart_busy;
    reg uart_send = 0;
    reg [7:0] uart_data;

    uart_transmit uart (
        .clk(clk),
        .data(uart_data),
        .send(uart_send),
        .tx(uart_tx),
        .busy(uart_busy)
    );

    // === 2-byte Send FSM ===
    reg [15:0] sample_buffer;
    reg send_low_byte = 0;

    always @(posedge clk) begin
        if (!uart_busy && mic_valid && !uart_send && !send_low_byte) begin
            sample_buffer <= mic_sample;
            uart_data <= mic_sample[15:8];  // MSB
            uart_send <= 1;
            send_low_byte <= 1;
        end else if (!uart_busy && send_low_byte && !uart_send) begin
            uart_data <= sample_buffer[7:0];  // LSB
            uart_send <= 1;
            send_low_byte <= 0;
        end else begin
            uart_send <= 0;
        end
    end

endmodule
