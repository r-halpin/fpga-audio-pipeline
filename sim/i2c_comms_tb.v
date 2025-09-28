module i2c_comms_tb;

    // Inputs to DUT (device under test)
    reg clk;
    reg rst;
    
    // Bidirectional SDA and SCL signals
    wire scl;
    wire sda;
    
    
    
    pullup p1(sda);  // Add pull-up to SDA
    pullup p2(scl);  // Add pull-up to SCL

    
    // Parameters
    parameter CLK_PERIOD = 10; // 100 MHz clock period in ns

    // Instantiate the DUT (i2c_master module)
    i2c_comms DUT (
        .clk(clk),
        .rst(rst),
        .scl(scl),
        .sda(sda)
        
    );
    
   

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Apply reset
        rst = 1;
        #100;  // Wait 100 ns
        rst = 0;

        // Wait for some time and observe
        #10000;
        
        // Apply another reset
        rst = 1;
        #100;
        rst = 0;

        // Wait for further observation
        #50000;
        
        // End simulation
        $stop;
    end

    // Monitor to check the LED states (for debugging)
    initial begin
        $monitor("Time: %0t, State: %b, SDA: %b, SCL: %b, SDA_OUT: %b", $time, DUT.state, sda, scl, DUT.sda_out);
        $dumpfile("waveform.vcd");
    $dumpvars(0, DUT.sda_out); // Add sda_out for waveform tracing
    $dumpvars(0, DUT); // Optionally, dump all DUT signals
    end

endmodule
