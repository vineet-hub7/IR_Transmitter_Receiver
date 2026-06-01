module uart_rx #(parameter CLKS_PER_BIT = 434) (
input i_clk,
input rx,
output reg rx_done = 1'b0,
output reg [7:0] rx_byte = 8'd0);
reg rx_s = 1'b1, rx_p = 1'b1;
always @(posedge i_clk) begin rx_p <= rx; rx_s <= rx_p; end
reg [1:0] state = 2'd0;
reg [9:0] cnt = 10'd0;
reg [2:0] rxbit = 3'd0;
reg [7:0] rxbuf = 8'd0;
always @(posedge i_clk) begin
rx_done <= 1'b0;
case (state)
2'd0: if (!rx_s) begin cnt <= 10'd0; state <= 2'd1; end
2'd1: if (cnt == CLKS_PER_BIT/2 - 1) begin
if (!rx_s) begin cnt <= 10'd0; rxbit <= 3'd0; state <= 2'd2; end
else state <= 2'd0;
end else cnt <= cnt + 10'd1;
2'd2: if (cnt == CLKS_PER_BIT - 1) begin
cnt <= 10'd0; rxbuf <= {rx_s, rxbuf[7:1]};
if (rxbit == 3'd7) state <= 2'd3; else rxbit <= rxbit + 3'd1;
end else cnt <= cnt + 10'd1;
2'd3: if (cnt == CLKS_PER_BIT - 1) begin
rx_done <= 1'b1; rx_byte <= rxbuf; state <= 2'd0; cnt <= 10'd0;
end else cnt <= cnt + 10'd1;
endcase
end
endmodule