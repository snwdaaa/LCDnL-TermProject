module u_game_button (
    input clk,              // 시스템 클럭
    input rst,              // 리셋
    input i_tick,           // 1ms 틱 (디바운싱 시간 측정용)
    input [3:0] i_btn,      // 실제 보드의 버튼 입력 (4개)
    
    // 정제된 출력 신호 (역할별 분리)
    output o_start,         // 게임 시작 (One-shot)
    output o_restart,       // 게임 재시작 (One-shot)
    output [1:0] o_play     // 플레이 버튼 2개 (One-shot)
);

    // [1] 버튼 매핑 정의 (사용하기 편하게 인덱스 정의)
    // 보드의 버튼 순서에 따라 매핑을 변경할 수 있습니다.
    localparam IDX_START   = 0;
    localparam IDX_RESTART = 1;
    localparam IDX_PLAY_L  = 2;
    localparam IDX_PLAY_R  = 3;

    // [2] 내부 레지스터 선언
    reg [3:0] btn_stable;   // 디바운싱이 완료된 안정적인 상태
    reg [3:0] btn_prev;     // 엣지 검출을 위한 이전 상태 저장
    
    // 각 버튼별로 채터링을 거르기 위한 카운터 (4개)
    reg [4:0] debounce_cnt [0:3]; 
    parameter DEBOUNCE_TIME = 20; // 20ms 동안 신호가 유지되어야 인정

    integer i;

    // [3] 디바운싱 로직 (Debouncing)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_stable <= 4'b0000;
            for (i=0; i<4; i=i+1) debounce_cnt[i] <= 0;
        end else if (i_tick) begin
            for (i=0; i<4; i=i+1) begin
                // 입력(i_btn)과 현재 안정된 상태(btn_stable)가 다르면 카운트 시작
                if (i_btn[i] != btn_stable[i]) begin
                    if (debounce_cnt[i] >= DEBOUNCE_TIME - 1) begin
                        btn_stable[i] <= i_btn[i]; // 20ms 경과 후 상태 업데이트
                        debounce_cnt[i] <= 0;
                    end else begin
                        debounce_cnt[i] <= debounce_cnt[i] + 1;
                    end
                end else begin
                    debounce_cnt[i] <= 0; // 노이즈였다면 카운터 초기화
                end
            end
        end
    end

    // [4] 엣지 검출 로직 (Edge Detection)
    // 버튼이 0 -> 1로 변하는 순간(Rising Edge)만 1을 출력
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_prev <= 4'b0000;
        end else begin
            btn_prev <= btn_stable;
        end
    end

    // 현재는 1이고, 이전엔 0이었던 순간 (Rising Edge)
    wire [3:0] btn_rise = btn_stable & ~btn_prev;

    // [5] 출력 할당 (역할 분배)
    assign o_start   = btn_rise[IDX_START];
    assign o_restart = btn_rise[IDX_RESTART];
    assign o_play    = {btn_rise[IDX_PLAY_R], btn_rise[IDX_PLAY_L]};

endmodule