`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.07.2025 21:46:40
// Design Name: 
// Module Name: uart_transmit_tb
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



module uart_transmit_tb;

    // Testbench signals
    reg clk = 0;
    reg [7:0] data = 8'b01010101;
    reg send = 0;
    wire tx;
    wire busy;

    // Instantiate the DUT (Device Under Test)
    uart_transmit #(
        .CLK_FREQ(100_000_000),
        .BAUD(115200)
    ) uut (
        .clk(clk),
        .data(data),
        .send(send),
        .tx(tx),
        .busy(busy)
    );

    // Clock generation: 100 MHz (10 ns period)
    always #5 clk = ~clk;

    // Main test procedure
    initial begin
        $display("UART Transmitter Testbench Starting");

        // Dump everything to VCD file
        $dumpfile("uart_transmit_tb.vcd");
        $dumpvars(0, uart_transmit_tb);  // dump everything under testbench, recursively

        // Display important initial values to force simulation
        $display("Initial tx = %b, busy = %b", tx, busy);

        // Wait for setup
        #100;

        // Send a byte
        data = 8'b01110101;
        send = 1;
        #10;  // 1 clock cycle at 100 MHz
        send = 0;

        // Wait for UART to go busy and then finish
        wait (busy == 1);
        wait (busy == 0);

        $display("Transmission complete at time %0t", $time);

        #100000000;  // Wait a bit longer before finishing
        $finish;
    end

    // Optional: Watch tx and internals in real time
    always @(posedge clk) begin
        $display("T=%0t | tx=%b | busy=%b | bit_index=%0d | clk_count=%0d | shift_reg=%b",
                 $time, tx, busy,
                 uart_transmit_tb.uut.bit_index,
                 uart_transmit_tb.uut.clk_count,
                 uart_transmit_tb.uut.shift_reg);
    end

endmodule
