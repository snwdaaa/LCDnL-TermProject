module piezo_ctrl (
    input clk,              // 시스템 클럭 (50MHz)
    input rst,
    input i_play_en,        // 1일 때만 소리 재생 (0이면 조용히)
    input [31:0] i_cnt_limit, // 주파수 결정을 위한 카운터 값 (외부에서 넣어줌)
    output reg o_piezo      // 피에조 부저로 나가는 신호
);

    reg [31:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 0;
            o_piezo <= 0;
        end else begin
            // 소리 재생 허가(Enable)가 1일 때만 동작
            if (i_play_en) begin
                // 6주차 실습 2의 원리 적용
                // 카운터가 목표값(반주기)에 도달하면
                if (cnt >= i_cnt_limit) begin
                    cnt <= 0;           // 카운터 초기화
                    o_piezo <= ~o_piezo; // 신호 반전 (0->1, 1->0)
                end else begin
                    cnt <= cnt + 1;     // 계속 셈
                end
            end else begin
                // 소리를 끄라고 하면 초기화
                cnt <= 0;
                o_piezo <= 0;
            end
        end
    end

endmodule