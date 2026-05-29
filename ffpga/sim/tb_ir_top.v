`timescale 1ns / 1ps
`include "../src/carrier_generator.v"
`include "../src/nec_encoder.v"
`include "../src/nec_decoder.v"
`include "../src/modulator.v"

module tb_ir_top();
reg clk = 0;
reg mcu_sck = 0;
reg mcu_sdi = 0;
reg mcu_tx_en = 0;
wire mcu_sdo;
wire mcu_tx_busy;
wire mcu_rx_valid;
wire ir_out;

reg [10:0] carrier_hold = 11'd0;
always @(posedge clk)
if (ir_out)
carrier_hold <= 11'd1316;
else if (carrier_hold > 0)
carrier_hold <= carrier_hold - 11'd1;
wire tsop_in = (carrier_hold > 0) ? 1'b0 : 1'b1;
ir_top dut (.i_clk(clk),.mcu_sck(mcu_sck),.mcu_sdi(mcu_sdi),.mcu_tx_en(mcu_tx_en),.mcu_sdo(mcu_sdo),.mcu_sdo_en(),.mcu_tx_busy(mcu_tx_busy),
.mcu_tx_busy_en(),.mcu_rx_valid(mcu_rx_valid),.mcu_rx_valid_en (),.tsop_in(tsop_in),.ir_out(ir_out),.ir_out_en(),.o_clk_en(),.oc_en());

always #10 clk = ~clk;

task spi_shift_out;
input [15:0] data;
integer i;
begin
for (i = 0; i < 16; i = i + 1) begin
@(negedge clk);
mcu_sdi = data[i];
#50;
mcu_sck = 1;
#200;
mcu_sck = 0;
#100;
end
mcu_sdi = 0;
end
endtask

task spi_shift_in;
output [15:0] data;
integer i;
reg [15:0] tmp;
begin
tmp = 0;
for (i = 0; i < 16; i = i + 1) begin
tmp = (tmp << 1) | mcu_sdo;
#100;
mcu_sck = 1;
#200;
mcu_sck = 0;
#100;
end
data = tmp;
end
endtask

task run_test;
input [15:0] tx_data;
input [15:0] expected;
input [63:0] label;
reg [15:0] rx_data;
reg [7:0] rx_addr, rx_cmd;
begin
spi_shift_out(tx_data);
repeat(2) @(posedge clk);
mcu_tx_en = 1;
repeat(5) @(posedge clk);
mcu_tx_en = 0;
wait(mcu_tx_busy);
@(negedge mcu_tx_busy);
wait(mcu_rx_valid);
spi_shift_in(rx_data);
if (rx_data === expected)
$display("PASS [%s]: got 0x%04X", label, rx_data);
else begin
$display("FAIL [%s]: expected 0x%04X got 0x%04X", label, expected, rx_data);
fail_count = fail_count + 1;
end
#10000;
end
endtask

initial begin
$dumpfile("tb_ir_top.vcd");
$dumpvars(0, tb_ir_top.clk,
tb_ir_top.mcu_sck,
tb_ir_top.mcu_sdi,
tb_ir_top.mcu_tx_en,
tb_ir_top.tsop_in,
tb_ir_top.mcu_sdo,
tb_ir_top.mcu_tx_busy,
tb_ir_top.mcu_rx_valid,
tb_ir_top.ir_out);
end

integer fail_count = 0;
initial begin
    $display("=== NEC IR Loopback Tests | 50 MHz ===");
    #500;
    run_test(16'h3412, 16'h3412, "DATA   addr=0x12 cmd=0x34");
    run_test(16'hFFFF, 16'hFFFF, "REPEAT 0xFFFF");
    $display("======================================");
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", fail_count);
    $display("======================================");
    $finish;
end

initial begin
    #400_000_000;
    $display("[TIMEOUT] exceeded 400ms");
    $finish;
end

endmodule
