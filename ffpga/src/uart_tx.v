module uart_tx #(parameter CLKS_PER_BIT = 434) (
input i_clk,
input tx_start,
input [7:0] tx_byte,
output reg tx = 1'b1,
output reg tx_done = 1'b0,
output tx_busy);
reg [1:0] state = 2'd0;
reg [9:0] cnt = 10'd0;
reg [2:0] bit_idx = 3'd0;
reg [7:0] tx_buf = 8'd0;
assign tx_busy = |state;
always @(posedge i_clk) begin
tx_done <= 1'b0;
case (state)
2'd0: begin
tx <= 1'b1;
if (tx_start) begin tx_buf <= tx_byte; tx <= 1'b0; cnt <= 10'd0; state <= 2'd1; end
end
2'd1: if (cnt == CLKS_PER_BIT - 1) begin cnt <= 10'd0; bit_idx <= 3'd0; tx <= tx_buf[0]; state <= 2'd2; end
else cnt <= cnt + 10'd1;
2'd2: if (cnt == CLKS_PER_BIT - 1) begin
cnt <= 10'd0;
if (bit_idx == 3'd7) begin tx <= 1'b1; state <= 2'd3; end
else begin bit_idx <= bit_idx + 3'd1; tx <= tx_buf[bit_idx + 3'd1]; end
end else cnt <= cnt + 10'd1;
2'd3: if (cnt == CLKS_PER_BIT - 1) begin tx_done <= 1'b1; cnt <= 10'd0; state <= 2'd0; end
else cnt <= cnt + 10'd1;
endcase
end
endmodule