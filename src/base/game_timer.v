// 분주기에서 만든 tick 신호 받아서
// 게임 시작 후 총 몇 ms 지났는지 누적 시간 셈

module game_timer (
    input clk, // 시스템 클럭
    input rst,
    input i_tick, // 분주기에서 오는 1ms 틱 신호
    output reg [31:0] cur_time // 현재 게임 시간 (ms 단위)
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cur_time <= 0;
        end else begin
            if (i_tick) begin
                cur_time <= cur_time + 1; // 1ms 틱이 들어올 때만 시간 증가
            end
        end
    end
endmodule