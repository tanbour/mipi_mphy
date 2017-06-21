// State machine for Type-1 M-PHY-TX
module m_phy_tx_sm #(
    parameter RESET_COMPLETION = 16,
    parameter T_ACTIVE = 16,
    parameter T_LINE_RESET = 16,
    parameter T_HS_PREPARE = 16,
    parameter T_PWM_PREPARE = 16
) (
    input  logic clk,
    input  logic reset,
    input  logic power_on,
    input  logic phy_reset,
    input  logic sap_reset,
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

typedef enum {ACTIVATED, LINE_RESET, POWERED, UNPOWERED, DISABLED, HIBERN8, SLEEP, PWM_BURST, LINE_CFG, STALL, HS_BURST} state_type;

state_type state;

logic [31:0] count = {32{1'b0}};

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
    end else if (sap_reset) begin
        state <= LINE_RESET;
        count <= 0;
    end else begin
        case (state)
            LINE_RESET : begin
                if (count >= T_LINE_RESET-1 && line_state == DIF_N) begin
                    state <= SLEEP;
                    count <= 0;
                end else if (line_state == DIF_P) begin
                    count <= count + 1;
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
                    count <= 0;
                end else if (count >= T_ACTIVE-1 && line_state == DIF_N) begin
                    state <= STALL;
                    count <= 0;
                end else if (line_state == DIF_N) begin
                    count <= count + 1;
                end else begin
                    state <= SLEEP;
                    count <= 0;
                end
            end
            SLEEP : begin
                if (rct) begin
                    state <= HIBERN8;
                    count <= 0;
                end else if (line_state == DIF_N) begin
                    count <= 0;
                end else if (count >= T_PWM_PREPARE-1 && line_state == DIF_P) begin
                    state <= PWM_BURST;
                    count <= 0;
                end else if (line_state == DIF_P) begin
                    count <= count + 1;
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
                    count <= 0;
                end else if (line_state == DIF_N) begin
                    count <= 0;
                end else if (count >= T_HS_PREPARE-1 && line_state == DIF_P) begin
                    state <= HS_BURST;
                    count <= 0;
                end else if (line_state == DIF_P) begin
                    count <= count + 1;
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
