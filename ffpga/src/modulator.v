(* top *) module ir_top (
(* iopad_external_pin, clkbuf_inhibit *) input i_clk,
(* iopad_external_pin *) input  mcu_sck,
(* iopad_external_pin *) input  mcu_sdi,
(* iopad_external_pin *) input  mcu_tx_en,
(* iopad_external_pin *) output mcu_sdo,
(* iopad_external_pin *) output mcu_sdo_en,
(* iopad_external_pin *) output reg mcu_tx_busy = 1'b0,
(* iopad_external_pin *) output mcu_tx_busy_en,
(* iopad_external_pin *) output reg mcu_rx_valid = 1'b0,
(* iopad_external_pin *) output mcu_rx_valid_en,
(* iopad_external_pin *) input  tsop_in,
(* iopad_external_pin *) output reg ir_out = 1'b0,
(* iopad_external_pin *) output ir_out_en,
(* iopad_external_pin *) output o_clk_en,
(* iopad_external_pin *) output oc_en);
assign o_clk_en       = 1'b1;
assign oc_en          = 1'b1;
assign ir_out_en      = 1'b1;
assign mcu_sdo_en     = 1'b1;
assign mcu_tx_busy_en = 1'b1;
assign mcu_rx_valid_en = 1'b1;
reg sck_s1=1'b0, sck_s2=1'b0, sck_s3=1'b0;
always @(posedge i_clk) begin
sck_s1 <= mcu_sck;
sck_s2 <= sck_s1;
sck_s3 <= sck_s2;
end
wire sck_rise = sck_s2 & ~sck_s3;
wire mod_enable;
wire tx_busy;
nec_encoder u_encoder (
.i_clk(i_clk), .sdi(mcu_sdi), .sck(mcu_sck), .send(mcu_tx_en),
.mod_enable(mod_enable), .busy(tx_busy));
always @(posedge i_clk) mcu_tx_busy <= tx_busy;
wire carrier;
carrier_generator u_carrier (
.i_clk(i_clk), .enable(mod_enable), .carrier(carrier));
always @(posedge i_clk) ir_out <= carrier;
wire [7:0] rx_addr;
wire [7:0] rx_cmd;
wire rx_valid;
wire rx_repeat;
nec_decoder u_decoder (
.i_clk(i_clk), .tsop_in(tsop_in),
.rx_addr(rx_addr), .rx_cmd(rx_cmd),
.rx_valid(rx_valid), .rx_repeat(rx_repeat));
reg [15:0] spi_out_shreg = 16'd0;
always @(posedge i_clk) begin
if (rx_valid) begin
spi_out_shreg <= {rx_cmd, rx_addr};
mcu_rx_valid <= 1'b1;
end else if (rx_repeat) begin
spi_out_shreg <= 16'hFFFF;
mcu_rx_valid <= 1'b1;
end else if (sck_rise && !tx_busy) begin
spi_out_shreg <= {spi_out_shreg[14:0], 1'b0};
mcu_rx_valid <= 1'b0;
end
end
assign mcu_sdo = spi_out_shreg[15];
endmodule
