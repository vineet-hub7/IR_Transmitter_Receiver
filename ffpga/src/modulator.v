(* top *) module ir_top (
(* iopad_external_pin, clkbuf_inhibit *) input i_clk,
(* iopad_external_pin *) input uart_rx,
(* iopad_external_pin *) output uart_tx,
(* iopad_external_pin *) output uart_tx_en,
(* iopad_external_pin *) input tsop_in,
(* iopad_external_pin *) output reg ir_out = 1'b0,
(* iopad_external_pin *) output ir_out_en,
(* iopad_external_pin *) output o_clk_en);
assign o_clk_en = 1'b1;
assign ir_out_en = 1'b1; assign uart_tx_en = 1'b1;
wire rx_done; wire [7:0] rx_byte;
uart_rx u_urx (.i_clk(i_clk), .rx(uart_rx), .rx_done(rx_done), .rx_byte(rx_byte));
wire ut_done, ut_busy, ut_tx;
reg  ut_start = 1'b0; reg [7:0] ut_byte = 8'd0;
uart_tx u_utx (.i_clk(i_clk), .tx_start(ut_start), .tx_byte(ut_byte),
.tx(ut_tx), .tx_done(ut_done), .tx_busy(ut_busy));
assign uart_tx = ut_tx;
reg [7:0] br_addr = 8'd0, br_cmd = 8'd0;
reg br_rep = 1'b0, nec_send = 1'b0;
reg [1:0] br_st = 2'd0;
always @(posedge i_clk) begin
nec_send <= 1'b0;
case (br_st)
2'd0: if (rx_done) begin
br_rep <= (rx_byte == 8'h02); br_st <= 2'd1;
end
2'd1: if (rx_done) begin br_addr <= rx_byte; br_st <= 2'd2; end
2'd2: if (rx_done) begin
br_cmd <= rx_byte;
if (!nec_busy) begin nec_send <= 1'b1; br_st <= 2'd0; end
else br_st <= 2'd3;
end
2'd3: if (!nec_busy) begin nec_send <= 1'b1; br_st <= 2'd0; end
endcase
end
wire mod_enable, nec_busy;
nec_encoder u_enc (.i_clk(i_clk),.addr(br_addr),.cmd(br_cmd),
.is_repeat(br_rep),.send(nec_send),.mod_enable(mod_enable),.busy(nec_busy));
wire carrier;
carrier_generator u_car (.i_clk(i_clk),.enable(mod_enable),.carrier(carrier));
always @(posedge i_clk) ir_out <= carrier;
wire [7:0] rx_addr, rx_cmd;
wire rx_valid, rx_repeat;
nec_decoder u_dec (.i_clk(i_clk),.tsop_in(tsop_in),
.rx_addr(rx_addr),.rx_cmd(rx_cmd),.rx_valid(rx_valid),.rx_repeat(rx_repeat));
reg [7:0] ut_addr_r = 8'd0, ut_cmd_r = 8'd0;
reg [1:0] ut_st = 2'd0;
always @(posedge i_clk) begin
ut_start <= 1'b0;
case (ut_st)
2'd0: if (rx_valid || rx_repeat) begin
ut_addr_r <= rx_addr; ut_cmd_r <= rx_cmd;
ut_byte <= rx_repeat ? 8'h02 : 8'h01;
ut_start <= 1'b1; ut_st <= 2'd1;
end
2'd1: if (ut_done) begin ut_byte <= ut_addr_r; ut_start <= 1'b1; ut_st <= 2'd2; end
2'd2: if (ut_done) begin ut_byte <= ut_cmd_r;  ut_start <= 1'b1; ut_st <= 2'd3; end
2'd3: if (ut_done) ut_st <= 2'd0;
endcase
end
endmodule