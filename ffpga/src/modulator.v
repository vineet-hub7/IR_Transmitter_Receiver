(* top *) module ir_top (
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,

    // 2-wire bit-bang from MCU (external jumper wires)
    (* iopad_external_pin *) input  data_in,     // GPIO0_IN [PIN 13] <- MCU GPIO5
    (* iopad_external_pin *) input  clk_in,      // GPIO1_IN [PIN 14] <- MCU GPIO6

    // Data output to MCU (external jumper wire)
    (* iopad_external_pin *) output reg data_out = 1'b0,  // GPIO18_OUT [PIN 9] -> MCU GPIO7
    (* iopad_external_pin *) output data_out_en,           // GPIO18_OE  [PIN 9]

    // IR output
    (* iopad_external_pin *) input  tsop_in,     // GPIO8_IN [PIN 23] <- PMOD connector
    (* iopad_external_pin *) output reg ir_out = 1'b0,  // GPIO7_OUT [PIN 20]
    (* iopad_external_pin *) output ir_out_en,          // GPIO7_OE  [PIN 20]

    // FPGA LED
    (* iopad_external_pin *) output reg fpga_led = 1'b0, // GPIO16_OUT [PIN 7]
    (* iopad_external_pin *) output fpga_led_en          // GPIO16_OE  [PIN 7]
);

    assign clk_en      = 1'b1;
    assign ir_out_en   = 1'b1;
    assign fpga_led_en = 1'b1;
    assign data_out_en = 1'b1;

    // --- Synchronize external inputs ---
    reg [2:0] clk_sync  = 3'b000;
    reg [2:0] data_sync = 3'b000;
    always @(posedge clk) begin
        clk_sync  <= {clk_sync[1:0], clk_in};
        data_sync <= {data_sync[1:0], data_in};
    end
    wire ext_clk_rise = ~clk_sync[2] & clk_sync[1];
    wire ext_data_bit = data_sync[2];

    reg [24:0] led_cnt   = 25'd0;
    reg        got_decode = 1'b0;
    always @(posedge clk) begin
        led_cnt <= led_cnt + 1;
        if (dec_valid || dec_repeat) got_decode <= 1'b1;
        if (got_decode)
            fpga_led <= 1'b1;
        else if (led_cnt == 0)
            fpga_led <= ~fpga_led;
    end

    // =========================================================
    //  MCU -> FPGA: 24-bit shift register for TX commands
    // =========================================================
    reg [23:0] shift_reg = 24'd0;
    reg [4:0]  bit_cnt   = 5'd0;
    reg        cmd_ready = 1'b0;
    reg [19:0] timeout   = 20'd0;

    always @(posedge clk) begin
        cmd_ready <= 1'b0;
        if (ext_clk_rise) begin
            shift_reg <= {shift_reg[22:0], ext_data_bit};
            timeout   <= 20'd0;
            if (bit_cnt == 5'd23) begin
                cmd_ready <= 1'b1;
                bit_cnt   <= 5'd0;
            end else
                bit_cnt <= bit_cnt + 5'd1;
        end else if (timeout < 20'd500000)
            timeout <= timeout + 20'd1;
        else
            bit_cnt <= 5'd0;
    end

    // --- TX command parser ---
    reg [7:0] cmd_addr = 8'd0;
    reg [7:0] cmd_cmd  = 8'd0;
    reg       cmd_rep  = 1'b0;
    reg       nec_send = 1'b0;

    always @(posedge clk) begin
        nec_send <= 1'b0;
        // Only fire NEC encoder for type 0x01 (data) or 0x02 (repeat)
        // Ignore 0xFF (read cmd) and 0xFE (debug read)
        if (cmd_ready && !nec_busy &&
            (shift_reg[23:16] == 8'h01 || shift_reg[23:16] == 8'h02)) begin
            cmd_rep  <= (shift_reg[23:16] == 8'h02);
            cmd_addr <= shift_reg[15:8];
            cmd_cmd  <= shift_reg[7:0];
            nec_send <= 1'b1;
        end
    end

    // --- NEC Encoder ---
    wire mod_enable, nec_busy;
    nec_encoder u_enc (
        .i_clk     (clk),
        .addr      (cmd_addr),
        .cmd       (cmd_cmd),
        .is_repeat (cmd_rep),
        .send      (nec_send),
        .mod_enable(mod_enable),
        .busy      (nec_busy)
    );

    // --- 38 kHz Carrier ---
    wire carrier;
    carrier_generator u_car (
        .i_clk  (clk),
        .enable (mod_enable),
        .carrier(carrier)
    );

    always @(posedge clk) ir_out <= carrier;

    // =========================================================
    //  FPGA -> MCU: Serialize decoded NEC data on data_out
    // =========================================================
    // NEC Decoder
    wire [7:0] dec_addr, dec_cmd;
    wire       dec_valid, dec_repeat;
    wire [2:0] dec_state;
    wire [4:0] dec_bit_idx;
    nec_decoder u_dec (
        .i_clk      (clk),
        .tsop_in    (tsop_in),
        .rx_addr    (dec_addr),
        .rx_cmd     (dec_cmd),
        .rx_valid   (dec_valid),
        .rx_repeat  (dec_repeat),
        .dbg_state  (dec_state),
        .dbg_bit_idx(dec_bit_idx)
    );

    // =========================================================
    //  FPGA -> MCU return path  (RACE-FREE, read-before-clock)
    //
    //  - rx_status/addr/cmd are persistent registers.
    //    status: 0x00 = nothing, 0x81 = data, 0x82 = repeat
    //  - On a fresh TX command (0x01/0x02) the previous result is
    //    cleared and the reader is re-armed (rd_ptr = 0).
    //  - data_out continuously presents bit (23-rd_ptr) of the
    //    24-bit frame {status,addr,cmd}, MSB first.
    //  - Each falling edge of the MCU clock advances rd_ptr.
    //  - MCU reads data_out BEFORE issuing the clock, so it always
    //    samples a stable bit (no shift-out race).
    //  - data_out idles at status[7]: HIGH (1) only when valid data
    //    is pending, so the MCU can poll it as a "ready" flag.
    // =========================================================

    wire ext_clk_fall = clk_sync[2] & ~clk_sync[1];

    reg [7:0] rx_status = 8'd0;
    reg [7:0] rx_addr_r = 8'd0;
    reg [7:0] rx_cmd_r  = 8'd0;
    reg [4:0] rd_ptr    = 5'd24;   // 24 = idle (data_out forced 0)
    reg       skip_fall = 1'b0;    // swallow the trailing falling edge of a TX command

    wire [23:0] rd_frame = {rx_status, rx_addr_r, rx_cmd_r};
    wire is_tx_cmd = cmd_ready &&
                     (shift_reg[23:16] == 8'h01 || shift_reg[23:16] == 8'h02);

    always @(posedge clk) begin
        // Latch a freshly decoded frame
        if (dec_valid) begin
            rx_status <= 8'h81;
            rx_addr_r <= dec_addr;
            rx_cmd_r  <= dec_cmd;
        end else if (dec_repeat && rx_status == 8'h00) begin
            rx_status <= 8'h82;
            rx_addr_r <= 8'h00;
            rx_cmd_r  <= 8'h00;
        end

        // New TX command clears old result and re-arms reader.
        // The command's own trailing falling edge must NOT advance rd_ptr,
        // so arm skip_fall to swallow exactly one falling edge.
        if (is_tx_cmd) begin
            rx_status <= 8'h00;
            rd_ptr    <= 5'd0;
            skip_fall <= 1'b1;
        end else if (ext_clk_fall) begin
            if (skip_fall)
                skip_fall <= 1'b0;            // consume trailing command edge
            else if (rd_ptr < 5'd24)
                rd_ptr <= rd_ptr + 5'd1;      // real read clock
        end

        // Present current bit (registered output)
        if (rd_ptr < 5'd24)
            data_out <= rd_frame[23 - rd_ptr];
        else
            data_out <= 1'b0;
    end

endmodule
