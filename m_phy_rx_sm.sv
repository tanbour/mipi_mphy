// State machine for Type-1 M-PHY-RX
module m_phy_rx_sm #(
    parameter RESET_COMPLETION = 16,
    parameter T_LINE_RESET_DETECT = 100
) (
    input  logic clk,
    input  logic reset,
    input  logic power_on,
    input  logic phy_reset,
    input  logic rct,
    input  logic pwm_2_sleep,
    input  logic pwm_2_line_cfg,
    input  logic line_cfg_2_sleep,
    input  logic line_cfg_2_stall,
    input  logic hs_2_stall,
    input  logic hs_2_line_cfg,
    input  logic [1:0] line_state,
    output logic [1:0] phy_state,
    output logic busy
);

localparam DIF_N = 0;
localparam DIF_P = 1;
localparam DIF_Q = 2;
localparam DIF_Z = 3;

logic [1:0] line_state_r = DIF_N;

always_ff @(posedge clk) begin
    line_state_r <= line_state;
end

logic dif_p_2_dif_n;
logic dif_z_2_dif_n;
logic dif_n_2_dif_p;

assign dif_p_2_dif_n = line_state_r == DIF_P && line_state == DIF_N;
assign dif_z_2_dif_n = line_state_r == DIF_Z && line_state == DIF_N;
assign dif_n_2_dif_p = line_state_r == DIF_N && line_state == DIF_P;

typedef enum {ACTIVATED, LINE_RESET, POWERED, UNPOWERED, DISABLED, HIBERN8, SLEEP, PWM_BURST, LINE_CFG, STALL, HS_BURST} state_type;

state_type state;

logic [31:0] count = {32{1'b0}};
logic [31:0] count_timeout = {32{1'b0}};

logic line_reset_detect;

assign line_reset_detect = count_timeout >= T_LINE_RESET_DETECT-1;

always_ff @(posedge clk) begin
    if (reset) begin
        count_timeout <= 0;
    end else if (line_state == DIF_P && line_reset_detect) begin
        count_timeout <= 0;
    end else if (line_state == DIF_P) begin
        count_timeout <= count_timeout + 1;
    end else begin
        count_timeout <= 0;
    end
end

always_ff @(posedge clk) begin
    case (state)
        PWM_BURST : phy_state <= 2'b01;
        LINE_CFG  : phy_state <= 2'b10;
        HS_BURST  : phy_state <= 2'b11;
        default   : phy_state <= 2'b00;
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        state <= UNPOWERED;
        count <= 0;
    end else if (phy_reset) begin
        state <= DISABLED;
        count <= 0;
    end else if (line_reset_detect) begin
        state <= LINE_RESET;
        count <= 0;
    end else begin
        case (state)
            LINE_RESET : begin
                if (dif_p_2_dif_n) begin
                    state <= SLEEP;
                end
            end
            UNPOWERED : begin
                if (power_on) begin
                    state <= DISABLED;
                end
            end
            DISABLED : begin
                if (count >= RESET_COMPLETION-1) begin
                    state <= HIBERN8;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            HIBERN8 : begin
                if (line_state == DIF_Z) begin
                    state <= HIBERN8;
                end else if (dif_z_2_dif_n) begin
                    state <= STALL;
                end else begin
                    state <= SLEEP;
                end
            end
            SLEEP : begin
                if (rct) begin
                    state <= HIBERN8;
                end else if (line_state == DIF_N) begin
                    state <= SLEEP;
                end else if (dif_n_2_dif_p) begin
                    state <= PWM_BURST;
                end
            end
            PWM_BURST : begin
                if (pwm_2_sleep) begin
                    state <= SLEEP;
                end else if (pwm_2_line_cfg) begin
                    state <= LINE_CFG;
                end
            end
            LINE_CFG : begin
                if (rct) begin
                    state <= HIBERN8;
                end else if (line_cfg_2_sleep) begin
                    state <= SLEEP;
                end else if (line_cfg_2_stall) begin
                    state <= STALL;
                end
            end
            STALL : begin
                if (rct) begin
                    state <= HIBERN8;
                end else if (line_state == DIF_N) begin
                    state <= STALL;
                end else if (dif_n_2_dif_p) begin
                    state <= HS_BURST;
                end
            end
            HS_BURST : begin
                if (hs_2_stall) begin
                    state <= STALL;
                end else if (hs_2_line_cfg) begin
                    state <= LINE_CFG;
                end
            end
            default : begin
                state <= UNPOWERED;
                count <= 0;
            end
        endcase
    end
end

endmodule
