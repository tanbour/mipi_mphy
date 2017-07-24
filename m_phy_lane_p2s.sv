module m_phy_lane_p2s (
  input  logic clk,
  input  logic reset,
  input  logic enable,
  input  logic load,
  input  logic [9:0] parallel_in,
  output logic serial_out
);

logic [9:0] data;

always_ff @(posedge clk) begin
  if (reset) begin
    data <= {10{1'b0}};
  end else if (load && enable) begin
    data <= {parallel_in[8:0],1'b0};
  end else if (load) begin
    data <= parallel_in;
  end else if (enable) begin
    data <= {data[8:0],1'b0};
  end
end

assign serial_out = load && enable ? parallel_in[9] : data[9];

endmodule
