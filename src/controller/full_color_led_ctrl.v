module full_color_led_ctrl (
    input clk,              // 시스템 클럭
    input rst,              // 리셋
    input i_tick,           // 1ms 틱 (애니메이션 속도 조절용)
    input i_game_over,      // 1: 게임 종료(애니메이션 모드), 0: 게임 중(판정 모드)
    input [1:0] i_judge,    // 판정 결과 (00:None, 01:Miss, 10:Normal, 11:Perfect)
    
    // 보드 출력 핀 (각 4비트)
    output reg [3:0] o_fcl_r, // Red
    output reg [3:0] o_fcl_g, // Green
    output reg [3:0] o_fcl_b  // Blue
);

    // [1] 색상 정의 (4비트씩, 모두 1이면 최대 밝기) 
    // Red: R=1, G=0, B=0
    // Green: R=0, G=1, B=0
    // Yellow: R=1, G=1, B=0 (빛의 혼합)
    localparam COLOR_OFF = 12'h000;
    localparam COLOR_RED = 12'hF00;   // Miss
    localparam COLOR_YEL = 12'hFF0;   // Normal
    localparam COLOR_GRN = 12'h0F0;   // Perfect

    // [2] 게임 오버 애니메이션 타이머
    reg [31:0] anim_cnt;
    reg [1:0] anim_step; // 0:Red -> 1:Yellow -> 2:Green 순서 제어
    parameter ANIM_SPEED = 500; // 500ms마다 색 변경

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            anim_cnt <= 0;
            anim_step <= 0;
        end else if (i_game_over && i_tick) begin
            // 게임 오버 상태일 때만 타이머 동작
            if (anim_cnt >= ANIM_SPEED - 1) begin
                anim_cnt <= 0;
                // 0 -> 1 -> 2 -> 0 ... 무한 반복 (또는 멈추게 수정 가능)
                if (anim_step >= 2) anim_step <= 0;
                else anim_step <= anim_step + 1;
            end else begin
                anim_cnt <= anim_cnt + 1;
            end
        end
    end

    // [3] 출력 로직 (우선순위 MUX)
    // Combinational Logic: 입력 상태에 따라 즉시 색상 결정
    always @(*) begin
        if (rst) begin
            {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_OFF;
        end 
        else if (i_game_over) begin
            // [모드 1] 게임 종료: 순차 애니메이션 출력
            case (anim_step)
                0: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_RED;
                1: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_YEL;
                2: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_GRN;
                default: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_OFF;
            endcase
        end 
        else begin
            // [모드 2] 게임 중: 판정 결과 출력
            case (i_judge)
                2'b01: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_RED; // Miss
                2'b10: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_YEL; // Normal
                2'b11: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_GRN; // Perfect
                default: {o_fcl_r, o_fcl_g, o_fcl_b} = COLOR_OFF; // 대기 상태
            endcase
        end
    end

endmodule