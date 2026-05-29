`timescale 1ns / 1ps

module tb_ir_top;

    reg clk = 0;
    always #10 clk = ~clk;

    reg mcu_sck = 0;
    reg mcu_sdi = 0;
    reg mcu_tx_en = 0;
    wire mcu_sdo;
    wire mcu_rx_valid;
    wire mcu_tx_busy;

    wire ir_out;
    wire ir_out_en;
    wire o_clk_en;
    wire oc_en;
    wire tsop_in;

    ir_top u_dut (
        .i_clk(clk),
        .mcu_sck(mcu_sck),
        .mcu_sdi(mcu_sdi),
        .mcu_tx_en(mcu_tx_en),
        .mcu_sdo(mcu_sdo),
        .mcu_rx_valid(mcu_rx_valid),
        .mcu_tx_busy(mcu_tx_busy),
        .tsop_in(tsop_in),
        .ir_out(ir_out),
        .ir_out_en(ir_out_en),
        .o_clk_en(o_clk_en),
        .oc_en(oc_en)
    );

    assign tsop_in = ~u_dut.u_encoder.mod_enable;

    task shift_out_16(input [15:0] data);
        integer i;
        begin
            mcu_tx_en = 0;
            for (i = 0; i < 16; i = i + 1) begin
                mcu_sdi = data[i];
                #1000;
                mcu_sck = 1;
                #1000;
                mcu_sck = 0;
                #1000;
            end
            mcu_sdi = 0;
        end
    endtask

    task shift_in_16(output [15:0] data);
        integer i;
        begin
            data = 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                data = (data << 1) | mcu_sdo;
                #1000;
                mcu_sck = 1;
                #1000;
                mcu_sck = 0;
                #1000;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_ir_top_light.vcd");

        $dumpvars(0, mcu_tx_en, mcu_sck, mcu_sdi, mcu_sdo, mcu_rx_valid, mcu_tx_busy, ir_out, tsop_in);

        $display("Starting IR TX/RX Loopback Simulation...");

        $display("MCU: Shifting out 0x3412 (addr=0x12, cmd=0x34)");
        shift_out_16(16'h3412);

        $display("MCU: Pulsing TX Enable");
        mcu_tx_en = 1;
        #2000;
        mcu_tx_en = 0;

        wait (mcu_tx_busy == 1);
        $display("FPGA: Transmitting... (busy goes high)");
        wait (mcu_tx_busy == 0);
        $display("FPGA: Transmission finished. (busy goes low)");

        $display("MCU: Waiting for RX Valid...");
        wait (mcu_rx_valid == 1);
        $display("FPGA: RX Valid asserted!");

        begin : READ_NORMAL
            reg [15:0] rx_data;
            shift_in_16(rx_data);
            $display("MCU: Read RX Data = 0x%04X (Expected: 0x3412)", rx_data);
            if (rx_data == 16'h3412)
                $display(">>> TEST 1 PASS: Normal Frame Loopback <<<");
            else
                $display(">>> TEST 1 FAIL: Normal Frame Loopback <<<");
        end

        #50_000_000;

        $display("\nMCU: Shifting out 0xFFFF (Repeat Code)");
        shift_out_16(16'hFFFF);

        $display("MCU: Pulsing TX Enable");
        mcu_tx_en = 1;
        #2000;
        mcu_tx_en = 0;

        wait (mcu_tx_busy == 1);
        $display("FPGA: Transmitting repeat code... (busy goes high)");
        wait (mcu_tx_busy == 0);
        $display("FPGA: Transmission finished. (busy goes low)");

        $display("MCU: Waiting for RX Valid...");
        wait (mcu_rx_valid == 1);
        $display("FPGA: RX Valid asserted!");

        begin : READ_REPEAT
            reg [15:0] rx_data;
            shift_in_16(rx_data);
            $display("MCU: Read RX Data = 0x%04X (Expected: 0xFFFF)", rx_data);
            if (rx_data == 16'hFFFF)
                $display(">>> TEST 2 PASS: Repeat Code Loopback <<<");
            else
                $display(">>> TEST 2 FAIL: Repeat Code Loopback <<<");
        end

        #10_000_000;
        $display("Simulation Complete.");
        $finish;
    end

    initial begin
        #300_000_000;
        $display(">>> TIMEOUT: Simulation ran too long! <<<");
        $finish;
    end

endmodule
