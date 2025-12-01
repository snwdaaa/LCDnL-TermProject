module sys_base (
    input clk,
    input rst
    // ... 다른 입출력 포트 ...
);

    wire w_game_tick;      // 두 모듈을 이어주는 전선
    wire [31:0] w_cur_time; // 현재 시간을 담는 전선

    // 분주기 인스턴스 (Tick 생성)
    clk_div u_clk_div (
        .clk(clk),
        .rst(rst),
        .o_tick(w_game_tick)
    );

    // 타이머 인스턴스 (시간 계산)
    game_timer u_game_timer (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .cur_time(w_cur_time)
    );

endmodule