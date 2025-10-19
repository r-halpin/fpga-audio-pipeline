`timescale 1ns / 1ps

module i2c_comms(
    input  wire clk,            // 100 MHz system clock
    input  wire rst,            // Active-high reset
    output wire scl,            // I2C Clock (open-drain)
    inout  wire sda,            // I2C Data (open-drain)
    output reg  [15:0] data_out,// 16-bit ADS1115 conversion result
    output reg  new_data,        // Pulses high when new data is ready
    output wire [3:0] debug_state
);

    // === Parameters ===
    parameter I2C_ADDRESS = 7'b1001000;     // ADS1115 default (0x48)
    parameter CLK_DIVIDER = 499;            // 100 MHz -> ~100 kHz I2C 499
    parameter DELAY_BETWEEN_READS =120;  // Delay cycles between reads 
    parameter SHIFT_DELAY = 4;              // Shifted SCL delay

    // ADS1115 Register Config
    parameter CONFIG_REG_PTR  = 8'b00000001; // 0x01 → Config register pointer
    parameter CONFIG_MSB      = 8'b11000010; // 0xC3 → OS=1, MUX=100 (AIN0), PGA=001 (±4.096V), MODE=1 (single-shot) b11000010
    parameter CONFIG_LSB      = 8'b11100011; // 0x83 → DR=100 (128 SPS), COMP disabled
    parameter CONVERSION_PTR  = 8'b00000000; // 0x00 → Conversion register pointer

    // === Internal Registers ===
    reg [15:0] clk_count;
    reg scl_enable;
    reg [SHIFT_DELAY-1:0] scl_shift;
    wire scl_delayed;
    reg i2c_active;

    reg sda_out;
    reg sda_drive;

    reg [7:0] tx_byte;
    reg [7:0] rx_byte;
    reg [2:0] bit_count;
    reg [3:0] state;
    reg [3:0] byte_count;
    reg [31:0] delay_counter;
    
    reg freeze_scl_shift = 0;
    
    reg [7:0] next_tx_byte;

    reg rw_mode;               // 0 = write, 1 = read
    reg [15:0] read_buffer;
    reg config_done;
    
    reg skip_cycle = 0;
    reg stall_scl = 0;
    
    reg scl_delayed_prev;
    wire scl_falling = (scl_delayed_prev == 1 && scl_delayed == 0);

    // === States ===
    localparam IDLE          = 4'd0;
    localparam START         = 4'd1;
    localparam SEND_BYTE     = 4'd2;
    localparam WAIT_ACK_START = 4'd3;
    localparam ACK           = 4'd4;
    localparam RESTART       = 4'd5;
    localparam RESTART_RELEASE  = 4'd6;
    localparam READ_BYTE     = 4'd7;
    localparam READ_ACK      = 4'd8;
    localparam STOP          = 4'd9;
    localparam WAIT          = 4'd10;
    localparam RESTART_WAIT          = 4'd11;
    
    
    always @(posedge clk or posedge rst) begin
    if (rst)
        scl_delayed_prev <= 1'b1; // idle high
    else
        scl_delayed_prev <= scl_delayed;
end

    // === SCL Clock Generation (Shifted) ===
    always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_count  <= 0;
        scl_enable <= 1;
        scl_shift  <= {SHIFT_DELAY{1'b1}};  // idle high
        stall_scl  <= 0;
    end else begin
        // Always toggle the FSM clock
        if (clk_count >= CLK_DIVIDER) begin
            clk_count  <= 0;
            if (!stall_scl) begin
                scl_enable <= ~scl_enable;
            end else begin
                scl_enable <= scl_enable; // hold
                stall_scl  <= 0;          // only stall for one cycle
            end
        end else begin
            clk_count <= clk_count + 1;
        end

        // Only update physical SCL if transfer is active
        if (i2c_active)
            if (!freeze_scl_shift)begin
            scl_shift <= {scl_shift[SHIFT_DELAY-2:0], scl_enable};
            end
            else begin
            scl_shift <= {SHIFT_DELAY{1'b1}};
            end
        else
            scl_shift <= {SHIFT_DELAY{1'b1}};  // idle high when not active
    end
end

    assign scl_delayed = scl_shift[SHIFT_DELAY-1];

    // === Main FSM ===
    always @(posedge scl_enable or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            sda_drive <= 0;
            sda_out <= 1;
            delay_counter <= 0;
            bit_count <= 7;
            byte_count <= 0;
            rw_mode <= 0;
            config_done <= 0;
            i2c_active <= 0;
            data_out <= 0;
            new_data <= 0;
        end else begin
            case (state)

                // ====================
                IDLE: begin
                    i2c_active <= 0;
                    sda_drive <= 0;
                    sda_out <= 1;
                    new_data <= 0;
                    if (delay_counter >= DELAY_BETWEEN_READS) begin
                        delay_counter <= 0;
                        bit_count <= 7;
                        i2c_active <= 0;

                        if (!config_done) begin
                            rw_mode <= 0;
                            byte_count <= 3;
                            tx_byte <= {I2C_ADDRESS, 1'b0};
                        end else begin
                            rw_mode <= 0;
                            byte_count <= 1;
                            tx_byte <= {I2C_ADDRESS, 1'b0};
                        end
                        state <= START;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end

                // ====================
                START: begin
                    i2c_active <= 1;
                    sda_drive <= 1;
                    sda_out <= 0;
                    
                    state <= SEND_BYTE;
                end

                // ====================
                SEND_BYTE: begin
                    i2c_active <= 1;
                    sda_drive <= 1;
                    sda_out <= tx_byte[bit_count];
                    if (bit_count == 0) begin
                        bit_count <= 7;
                        state <= WAIT_ACK_START;
                    end else begin
                        bit_count <= bit_count - 1;
                    end
                end
                                                

                // ====================
                
                WAIT_ACK_START: begin
                    sda_drive <= 0;  // Release SDA
                    // === Decide next byte
                    if (!config_done) begin
                    case (byte_count)
                      3: next_tx_byte = CONFIG_REG_PTR; // 0x01
                      2: next_tx_byte = CONFIG_MSB;     // 0xC3
                      1: next_tx_byte = CONFIG_LSB;     // 0x83
                      default: next_tx_byte = 8'h00;
                    endcase
                  end else begin
                    // AFTER config: only write the Conversion Pointer (0x00)
                    next_tx_byte = CONVERSION_PTR;      // 0x00
                  end
                    
                    tx_byte <= next_tx_byte;
                    state <= ACK;
                end
                
                // ====================

                ACK: begin
                    i2c_active <= 1;
                    

                if (!rw_mode) begin
                   
                    if (byte_count > 0) begin
                        byte_count <= byte_count - 1;                
                    
                    
                    bit_count <= bit_count - 1;
                    sda_drive <= 1; 
                    sda_out <= tx_byte[7];
                    state <= SEND_BYTE;
                end else begin
                    if (!config_done) begin
                        config_done <= 1;
                        state <= STOP;
                    end else begin
                        //sda_drive <= 1; 
                        rw_mode <= 1;
                        byte_count <= 2;
                        tx_byte <= {I2C_ADDRESS, 1'b1};
                        state <= RESTART;
                    end
                end
            end else begin
                sda_drive <= 0; 
                state <= READ_BYTE;
            end
        end

                // ====================

                RESTART: begin
                    freeze_scl_shift <= 1;     // Freeze the delayed clock
                    sda_drive <= 1;
                    sda_out   <= 1;
                    state <= RESTART_WAIT;
                end

                // ====================
                
                RESTART_WAIT: begin
                    sda_out <= 0;              // Pull SDA low while SCL (delayed) is highsda_out <= 0; // SDA goes low while SCL is still high (delayed)sda_out <= 0; // Bring SDA low
                    state <= RESTART_RELEASE;    
                     end

                // ====================
                
                RESTART_RELEASE: begin
                    freeze_scl_shift <= 0;     // Resume delayed SCL shifting
                    state <= SEND_BYTE;
                    
                    end                    

                // ====================
                
                READ_BYTE: begin
                i2c_active <= 1;
                sda_drive <= 0; 
                rx_byte[bit_count] <= sda;
            
                if (bit_count == 0) begin
                    bit_count <= 7;
                    byte_count <= byte_count - 1;
                    sda_drive <= 1;
                    sda_out <= 0; // ACK
            
                    state <= READ_ACK;
            
                    // Move to READ_ACK and assign rx_byte into buffer there instead!
                end else begin
                    bit_count <= bit_count - 1;
                end
            end

                // ====================

                READ_ACK: begin
                    // ⬇️Only now rx_byte has full value - assign it
                    if (byte_count == 1)
                        read_buffer[15:8] <= rx_byte;
                    else if (byte_count == 0)
                        read_buffer[7:0] <= rx_byte;
                
                    if (byte_count > 0) begin
                        
                        state <= READ_BYTE;
                    end else begin
                        sda_drive <= 1;
                        sda_out <= 1; // NACK
                        state <= STOP;
                        data_out <= read_buffer;
                        new_data <= 1;
                    end
                end

                // ====================
                STOP: begin
                    sda_drive <= 1;
                    sda_out <= 0;
                    state <= WAIT;
                end

                // ====================
                
                WAIT: begin
                    sda_drive <= 0;
                    sda_out <= 1;
                    i2c_active <= 0;
                    state <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

    // === Open-Drain Assignments ===
    assign scl = scl_delayed ? 1'bz : 1'b0;
    assign sda = sda_drive ? sda_out : 1'bz;
    assign debug_state[0] = state[0];
    assign debug_state[1] = state[1];
    assign debug_state[2] = state[2];
    assign debug_state[3] = state[3];
    

endmodule
