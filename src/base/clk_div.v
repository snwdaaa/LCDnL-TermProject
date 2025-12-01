// 클럭 분주기
// 다른 모듈들에 1kHz 클럭 입력

module clk_div (
    input clk, // 시스템 클럭
    input rst,
    output reg o_tick // 잠깐 HIGH 되는 tick 신호
);

    // 50MHz -> 1kHz 변환을 위한 카운터 상한값
    //parameter CNT_MAX = 50000 - 1;
    parameter CNT_MAX = 50000 - 1; // 시뮬레이션 테스트용!! 테스트 끝나면 위의 값 사용
    
    reg [31:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 0;
            o_tick <= 0;
        end else begin
            if (cnt >= CNT_MAX) begin
                cnt <= 0;
                o_tick <= 1; // 1ms 되면 tick
            end else begin
                cnt <= cnt + 1;
                o_tick <= 0;
            end
        end
    end
endmodule