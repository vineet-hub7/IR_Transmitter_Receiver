module nec_encoder (
input i_clk,
input sdi,
input sck,
input send,
output reg mod_enable = 1'b0,
output reg busy = 1'b0);
reg sdi_s1=1'b0, sdi_s2=1'b0;
reg sck_s1=1'b0, sck_s2=1'b0, sck_s3=1'b0;
reg snd_s1=1'b0, snd_s2=1'b0, snd_s3=1'b0;
always @(posedge i_clk) begin
sdi_s1 <= sdi;
sdi_s2 <= sdi_s1;
sck_s1 <= sck;
sck_s2 <= sck_s1;
sck_s3 <= sck_s2;
snd_s1 <= send;
snd_s2 <= snd_s1;
snd_s3 <= snd_s2;
end
wire sck_rise = sck_s2 & ~sck_s3;
wire send_rise = snd_s2 & ~snd_s3;
reg [15:0] shreg = 16'd0;
always @(posedge i_clk)
if (sck_rise)
shreg <= {sdi_s2, shreg[15:1]};
localparam T_LEADER_BURST = 21'd450000,
T_LEADER_SPACE = 21'd225000,
T_REPEAT_SPACE = 21'd112500,
T_BIT_BURST = 21'd28125,
T_ZERO_SPACE = 21'd28125,
T_ONE_SPACE = 21'd84375,
T_STOP_BURST = 21'd28125,
T_FRAME_GAP = 21'd2000000;
localparam S_IDLE = 4'd0,
S_LEADER_BURST = 4'd1,
S_LEADER_SPACE = 4'd2,
S_REPEAT_SPACE = 4'd3,
S_BIT_BURST = 4'd4,
S_BIT_SPACE = 4'd5,
S_STOP_BURST = 4'd6,
S_FRAME_GAP = 4'd7;
reg [3:0] state = S_IDLE;
reg [20:0] timer = 21'd0;
reg [4:0] bit_idx = 5'd0;
reg [31:0] frame = 32'd0;
reg is_repeat = 1'b0;
always @(posedge i_clk) begin
case (state)
S_IDLE: begin
mod_enable <= 1'b0;
busy <= 1'b0;
if (send_rise) begin
if (shreg == 16'hFFFF)
is_repeat <= 1'b1;
else begin
is_repeat <= 1'b0;
frame <= {~shreg[15:8], shreg[15:8], ~shreg[7:0], shreg[7:0]};
end
timer <= 21'd0;
bit_idx <= 5'd0;
busy <= 1'b1;
state <= S_LEADER_BURST;
end
end
S_LEADER_BURST: begin
mod_enable <= 1'b1;
if (timer == T_LEADER_BURST - 1) begin
timer <= 21'd0;
state <= is_repeat ? S_REPEAT_SPACE : S_LEADER_SPACE;
end else
timer <= timer + 21'd1;
end
S_LEADER_SPACE: begin
mod_enable <= 1'b0;
if (timer == T_LEADER_SPACE - 1) begin
timer <= 21'd0;
state <= S_BIT_BURST;
end else
timer <= timer + 21'd1;
end
S_REPEAT_SPACE: begin
mod_enable <= 1'b0;
if (timer == T_REPEAT_SPACE - 1) begin
timer <= 21'd0;
state <= S_STOP_BURST;
end else
timer <= timer + 21'd1;
end
S_BIT_BURST: begin
mod_enable <= 1'b1;
if (timer == T_BIT_BURST - 1) begin
timer <= 21'd0;
state <= S_BIT_SPACE;
end else
timer <= timer + 21'd1;
end
S_BIT_SPACE: begin
mod_enable <= 1'b0;
if (timer == (frame[bit_idx] ? T_ONE_SPACE : T_ZERO_SPACE) - 1) begin
timer <= 21'd0;
if (bit_idx == 5'd31)
state <= S_STOP_BURST;
else begin
bit_idx <= bit_idx + 5'd1;
state <= S_BIT_BURST;
end
end else
timer <= timer + 21'd1;
end
S_STOP_BURST: begin
mod_enable <= 1'b1;
if (timer == T_STOP_BURST - 1) begin
mod_enable <= 1'b0;
timer <= 21'd0;
state <= S_FRAME_GAP;
end else
timer <= timer + 21'd1;
end
S_FRAME_GAP: begin
mod_enable <= 1'b0;
if (timer == T_FRAME_GAP - 1) begin
busy <= 1'b0;
timer <= 21'd0;
state <= S_IDLE;
end else
timer <= timer + 21'd1;
end
default: state <= S_IDLE;
endcase
end
endmodule
