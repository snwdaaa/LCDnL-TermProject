module full_color_led_ctrl (
    input clk, rst, i_tick,
    input i_game_over,
    input [1:0] i_judge,    // 판정 결과 (Hold 신호)
 
    output reg [3:0] o_fcl_r, 
    output reg [3:0] o_fcl_g, 
    output reg [3:0] o_fcl_b
);
    localparam COLOR_OFF = 12'h000;
    localparam COLOR_RED = 12'hF00;   // Miss
    localparam COLOR_YEL = 12'hFF0;   // Normal
    localparam COLOR_GRN = 12'h0F0;   // Perfect

    reg [31:0] anim_cnt;
    reg [1:0] anim_step;
    parameter ANIM_SPEED = 500; // 0.5초마다 변경

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            anim_cnt <= 0;
            anim_step <= 0;
        end else if (i_game_over && i_tick) begin
            if (anim_cnt >= ANIM_SPEED - 1) begin
                anim_cnt <= 0;
                // 0 -> 1 -> 2 -> 0 순환
                if (anim_step >= 2) anim_step <= 0;
                else anim_step <= anim_step + 1;
            end else begin
                anim_cnt <= anim_cnt + 1;
            end
        end
    end

    always @(*) begin
        if (rst) begin
            {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_OFF;
        end 
        else if (i_game_over) begin
            // [모드 1] 게임 종료 애니메이션 (순서 변경!)
            // 요청하신 순서: 초록 -> 노랑 -> 빨강
            case (anim_step)
                0: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_GRN; // [수정] 1st: Green
                1: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_YEL; // [수정] 2nd: Yellow
                2: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_RED; // [수정] 3rd: Red
                default: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_OFF;
            endcase
        end 
        else begin
            // [모드 2] 게임 중 판정 표시
            case (i_judge)
                2'b01: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_RED;   // Miss
                2'b10: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_YEL;   // Normal
                2'b11: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_GRN;   // Perfect
                default: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_OFF;
            endcase
        end
    end

endmodule