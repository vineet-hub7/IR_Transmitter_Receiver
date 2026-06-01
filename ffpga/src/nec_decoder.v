module nec_decoder (
input i_clk,
input tsop_in,
output reg [7:0] rx_addr = 8'd0,
output reg [7:0] rx_cmd = 8'd0,
output reg rx_valid = 1'b0,
output reg rx_repeat = 1'b0);
reg tsop_s1=1'b1, tsop_s2=1'b1, tsop_s3=1'b1;
always @(posedge i_clk) begin
tsop_s1 <= tsop_in;
tsop_s2 <= tsop_s1;
tsop_s3 <= tsop_s2;
end
wire mark_start = ~tsop_s2 & tsop_s3;
wire mark_end = tsop_s2 & ~tsop_s3;
localparam MIN_LEADER_MARK  = 21'd337500,
MAX_LEADER_MARK = 21'd562500,
MIN_LEADER_SPACE = 21'd168750,
MAX_LEADER_SPACE = 21'd281250,
MIN_REPEAT_SPACE = 21'd84375,
MAX_REPEAT_SPACE = 21'd140625,
MIN_BIT_MARK = 21'd21000,
MAX_BIT_MARK = 21'd35000,
MIN_ZERO_SPACE = 21'd21000,
MAX_ZERO_SPACE = 21'd35000,
MIN_ONE_SPACE = 21'd63000,
MAX_ONE_SPACE = 21'd105000;
localparam S_IDLE = 3'd0,
S_LEADER_MARK = 3'd1,
S_LEADER_SPACE = 3'd2,
S_BIT_MARK = 3'd3,
S_BIT_SPACE = 3'd4,
S_STOP_BURST = 3'd5;
reg [2:0] state = S_IDLE;
reg [20:0] timer = 21'd0;
reg [4:0] bit_idx = 5'd0;
reg [31:0] frame = 32'd0;
always @(posedge i_clk) begin
rx_valid <= 1'b0;
rx_repeat <= 1'b0;
if (timer < 21'h1FFFFF)
timer <= timer + 21'd1;
case (state)
S_IDLE: begin
if (mark_start) begin
timer <= 21'd0;
state <= S_LEADER_MARK;
end
end
S_LEADER_MARK: begin
if (mark_end) begin
if (timer >= MIN_LEADER_MARK && timer <= MAX_LEADER_MARK) begin
timer <= 21'd0;
state <= S_LEADER_SPACE;
end else
state <= S_IDLE;
end else if (timer > MAX_LEADER_MARK)
state <= S_IDLE;
end
S_LEADER_SPACE: begin
if (mark_start) begin
if (timer >= MIN_LEADER_SPACE && timer <= MAX_LEADER_SPACE) begin
timer <= 21'd0;
bit_idx <= 5'd0;
state <= S_BIT_MARK;
end else if (timer >= MIN_REPEAT_SPACE && timer <= MAX_REPEAT_SPACE) begin
rx_repeat <= 1'b1;
state <= S_IDLE;
end else
state <= S_IDLE;
end else if (timer > MAX_LEADER_SPACE)
state <= S_IDLE;
end
S_BIT_MARK: begin
if (mark_end) begin
if (timer >= MIN_BIT_MARK && timer <= MAX_BIT_MARK) begin
timer <= 21'd0;
state <= S_BIT_SPACE;
end else
state <= S_IDLE;
end else if (timer > MAX_BIT_MARK)
state <= S_IDLE;
end
S_BIT_SPACE: begin
if (mark_start) begin
if (timer >= MIN_ZERO_SPACE && timer <= MAX_ZERO_SPACE)
frame[bit_idx] <= 1'b0;
else if (timer >= MIN_ONE_SPACE && timer <= MAX_ONE_SPACE)
frame[bit_idx] <= 1'b1;
else
state <= S_IDLE;
if ((timer >= MIN_ZERO_SPACE && timer <= MAX_ZERO_SPACE) ||
(timer >= MIN_ONE_SPACE  && timer <= MAX_ONE_SPACE)) begin
timer <= 21'd0;
if (bit_idx == 5'd31)
state <= S_STOP_BURST;
else begin
bit_idx <= bit_idx + 5'd1;
state <= S_BIT_MARK;
end
end
end else if (timer > MAX_ONE_SPACE)
state <= S_IDLE;
end
S_STOP_BURST: begin
if (mark_end) begin
if (timer >= MIN_BIT_MARK && timer <= MAX_BIT_MARK) begin
if (frame[7:0] == ~frame[15:8] && frame[23:16] == ~frame[31:24]) begin
rx_addr <= frame[7:0];
rx_cmd <= frame[23:16];
rx_valid <= 1'b1;
end
end
state <= S_IDLE;
end else if (timer > MAX_BIT_MARK)
state <= S_IDLE;
end
default: state <= S_IDLE;
endcase
end
endmodule