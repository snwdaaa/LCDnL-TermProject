module score_ctrl (
    input clk,
    input rst,
    input [1:0] i_judge,     // 판정 결과 (11:Perfect, 10:Normal, 01:Miss)
    output reg [15:0] o_score // 누적된 총 점수
);

    reg [1:0] judge_prev;    // 엣지 디텍션용 이전 상태 저장

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_score <= 0;
            judge_prev <= 0;
        end else begin
            judge_prev <= i_judge;

            // [핵심] 판정 신호가 변하는 순간(Rising Edge)에만 점수 합산
            // 00(Idle)이 아니고, 이전 상태와 다를 때 동작
            if (i_judge != 0 && i_judge != judge_prev) begin
                case (i_judge)
                    2'b11: o_score <= o_score + 2; // Perfect: +2점
                    2'b10: o_score <= o_score + 1; // Normal: +1점
                    2'b01: o_score <= o_score + 0; // Miss: +0점
                    default: ;
                endcase
            end
        end
    end
endmodule