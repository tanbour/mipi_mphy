module m_phy_lane_s2p (
  input  logic clk,
  input  logic reset,
  input  logic unlock,
  input  logic [9:0] comma_char,
  output logic [9:0] parallel_out,
  output logic data_valid,
  output logic allign_valid,
  input  logic serial_in
);

typedef enum {IDLE,WAIT,LOCK} state_type;
state_type state = IDLE;

logic [3:0] count = 4'd0;

logic [9:0] data [0:9];
logic [9:0] byte_allign;
logic [3:0] byte_allign_bin;

always_comb begin
  case (byte_allign)
    10'h001 : byte_allign_bin = 4'd0;
    10'h002 : byte_allign_bin = 4'd1;
    10'h004 : byte_allign_bin = 4'd2;
    10'h008 : byte_allign_bin = 4'd3;
    10'h010 : byte_allign_bin = 4'd4;
    10'h020 : byte_allign_bin = 4'd5;
    10'h040 : byte_allign_bin = 4'd6;
    10'h080 : byte_allign_bin = 4'd7;
    10'h100 : byte_allign_bin = 4'd8;
    10'h200 : byte_allign_bin = 4'd9;
    default : byte_allign_bin = 4'd0;
  endcase
end

integer i;
always_ff @(posedge clk) begin
  data[0] <= {data[0][8:0],serial_in};
  for (i=1; i<9; i++) begin
    data[i] <= data[i][8:0],data[i-1][9];
  end
end

always_ff @(posedge clk) begin
  if (reset) begin
    byte_allign <= {10{1'b0}};
  end else begin
    for (i=1; i<9; i++) begin
      byte_allign[i] <= comma_char == data[i] ? 1'b1 : 1'b0;
    end
  end
end

always_ff @(posedge clk) begin
  if (reset) begin
    parallel_out <= {10{1'b0}};
    allign_valid <= 1'b0;
  end else begin
    parallel_out <= data[byte_allign_bin];
    allign_valid <= state == LOCK;
  end
end

always_ff @(posedge clk) begin
  if (reset) begin
    state <= IDLE;
    count <= 4'd0;
  end else begin
    case (state)
      IDLE : begin
        if (count >= 4'd9) begin
          state <= WAIT;
          count <= 4'd0;
        end else begin
          count <= count + 1;
        end
      end
      WAIT : begin
        if (|byte_allign) begin
          state <= LOCK;
        end
      end
      LOCK : begin
        if (unlock) begin
          state <= WAIT;
        end
      end
      default : begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule
