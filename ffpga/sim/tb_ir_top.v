`timescale 1ns / 1ps
`include "../src/carrier_generator.v"
`include "../src/uart_rx.v"
`include "../src/uart_tx.v"
`include "../src/nec_encoder.v"
`include "../src/nec_decoder.v"
`include "../src/modulator.v"

module tb_ir_top();
reg clk = 0;
reg uart_rx = 1;
wire uart_tx;
wire uart_tx_en;
wire ir_out;
wire ir_out_en;

reg [10:0] carrier_hold = 11'd0;
always @(posedge clk)
  if (ir_out)
    carrier_hold <= 11'd1316;
  else if (carrier_hold > 0)
    carrier_hold <= carrier_hold - 11'd1;
wire tsop_in = (carrier_hold > 0) ? 1'b0 : 1'b1;

ir_top dut (
  .i_clk(clk),
  .uart_rx(uart_rx),
  .uart_tx(uart_tx),
  .uart_tx_en(uart_tx_en),
  .tsop_in(tsop_in),
  .ir_out(ir_out),
  .ir_out_en(ir_out_en),
  .o_clk_en());

always #10 clk = ~clk;

task uart_send_byte;
  input [7:0] data;
  integer i;
  begin
    // Start bit
    uart_rx = 1'b0;
    #8680;
    // Data bits (LSB first)
    for (i = 0; i < 8; i = i + 1) begin
      uart_rx = data[i];
      #8680;
    end
    // Stop bit
    uart_rx = 1'b1;
    #8680;
  end
endtask

task uart_send_cmd;
  input [7:0] cmd_type;
  input [7:0] addr;
  input [7:0] cmd;
  begin
    uart_send_byte(cmd_type);
    uart_send_byte(addr);
    uart_send_byte(cmd);
  end
endtask

task uart_read_byte;
  output [7:0] data;
  integer i;
  reg [7:0] tmp;
  begin
    // Wait for start bit (falling edge of uart_tx)
    @(negedge uart_tx);
    // Wait 1.5 bit times to sample in the middle of bit 0
    #13020;
    for (i = 0; i < 8; i = i + 1) begin
      tmp[i] = uart_tx;
      #8680;
    end
    data = tmp;
    // Wait remaining part of stop bit to clear
    #4340;
  end
endtask

task uart_read_resp;
  output [7:0] cmd_type;
  output [7:0] addr;
  output [7:0] cmd;
  begin
    uart_read_byte(cmd_type);
    uart_read_byte(addr);
    uart_read_byte(cmd);
  end
endtask

integer fail_count = 0;

task run_test;
  input [7:0] tx_type;
  input [7:0] tx_addr;
  input [7:0] tx_cmd;
  input [7:0] expected_type;
  input [7:0] expected_addr;
  input [7:0] expected_cmd;
  input [199:0] label;
  reg [7:0] rx_type;
  reg [7:0] rx_addr;
  reg [7:0] rx_cmd;
  begin
    $display("[%0t] Starting test: %s", $time, label);
    // Send UART command
    uart_send_cmd(tx_type, tx_addr, tx_cmd);
    
    // Wait for response over UART
    uart_read_resp(rx_type, rx_addr, rx_cmd);
    
    if (rx_type === expected_type && rx_addr === expected_addr && rx_cmd === expected_cmd) begin
      $display("PASS [%s]: got type=0x%02X addr=0x%02X cmd=0x%02X", label, rx_type, rx_addr, rx_cmd);
    end else begin
      $display("FAIL [%s]: expected type=0x%02X addr=0x%02X cmd=0x%02X, got type=0x%02X addr=0x%02X cmd=0x%02X", 
               label, expected_type, expected_addr, expected_cmd, rx_type, rx_addr, rx_cmd);
      fail_count = fail_count + 1;
    end
    #100000;
  end
endtask

initial begin
  $dumpfile("tb_ir_top.vcd");
  $dumpvars(1, tb_ir_top);
end

initial begin
    $display("=== NEC IR UART Loopback Tests | 50 MHz ===");
    #500;
    run_test(8'h01, 8'h12, 8'h34, 8'h01, 8'h12, 8'h34, "DATA   addr=0x12 cmd=0x34");
    run_test(8'h02, 8'h00, 8'h00, 8'h02, 8'h12, 8'h34, "REPEAT 0x02");
    $display("========================================");
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", fail_count);
    $display("========================================");
    $finish;
end

initial begin
    #400_000_000;
    $display("[TIMEOUT] exceeded 400ms");
    $finish;
end

endmodule
