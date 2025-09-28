`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.06.2025 20:30:17
// Design Name: 
// Module Name: uart_transmit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_transmit #(
    parameter CLK_FREQ = 100_000_000,   // FPGA clock frequency in Hz
    parameter BAUD     = 460800         // Baud rate
)(
    input wire clk,             // System clock
    input wire [7:0] data,      // Byte to transmit
    input wire send,            // Pulse high for one cycle to start transmission
    output reg tx = 1,          // UART TX line (idle high)
    output reg busy = 0         // High while transmitting
);

    // Number of clocks per UART bit
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD;

    // Internal state
    reg [13:0] clk_count = 0;           // Clock counter for bit timing
    reg [3:0] bit_index = 0;            // Which bit of the frame is being sent
    reg [9:0] shift_reg = 10'b1111111111;  // 10-bit UART frame: {stop, data[7:0], start}
    reg sending = 0;                    // Active transmission flag

    always @(posedge clk) begin
        if (!sending) begin
            // Idle state - wait for send trigger
            if (send) begin
                shift_reg <= {1'b1, data, 1'b0}; // Format: stop, data (MSB:LSB), start
                bit_index <= 0;
                clk_count <= 0;
                sending <= 1;
                busy <= 1;
            end
        end else begin
            // Actively sending
            tx <= shift_reg[0];  // Always drive tx with the current bit

            if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 0;
                shift_reg <= {1'b1, shift_reg[9:1]};  // Shift right, pad with stop bit
                bit_index <= bit_index + 1;

                if (bit_index == 9) begin
                    // Finished sending all 10 bits
                    sending <= 0;
                    busy <= 0;
                end
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

endmodule


