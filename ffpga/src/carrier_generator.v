module carrier_generator (
input i_clk,
input enable,
output reg carrier = 1'b0);
reg [9:0] counter = 10'd0;
reg enable_prev = 1'b0;
always @(posedge i_clk) begin
enable_prev <= enable;
if (!enable) begin
counter <= 10'd0;
carrier <= 1'b0;
end else if (!enable_prev) begin
counter <= 10'd0;
carrier <= 1'b1;
end else if (counter == 10'd657) begin
counter <= 10'd0;
carrier <= ~carrier;
end else
counter <= counter + 10'd1;
end
endmodule