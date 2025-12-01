module sys_base (
    input clk,              // 시스템 클럭 (50MHz)
    input rst,              // 리셋
    
    // 피에조 부저 출력 (유일한 판정 피드백)
    output o_piezo,
    
    // LCD 연결 핀
    output o_lcd_rs,
    output o_lcd_rw,
    output o_lcd_e,
    output [7:0] o_lcd_data,
    
    // 버튼 입력
    input [3:0] i_btn       // 버튼 입력 4개
);

    // ====================================================
    // 1. 내부 신호 선언
    // ====================================================
    wire w_game_tick;       // 1ms 틱
    wire [31:0] w_cur_time; // 현재 게임 시간
    
    // 노트 신호
    wire w_note_t1;         // 윗줄 노트
    wire w_note_t2;         // 아랫줄 노트
    wire w_game_end;
    
    // 버튼 신호 (채터링 제거됨)
    wire w_start_btn;
    wire w_restart_btn;
    wire [1:0] w_play_btn;  // [1]: Down(Track2), [0]: Up(Track1)
    
    // 피에조 제어 신호 (Judgement -> Piezo)
    wire w_play_en;         // 소리 재생 Enable
    wire [31:0] w_cnt_limit;// 재생할 주파수 값
    
    // 판정 결과 신호 (현재 사용 안 함, 추후 확장용)
    wire [1:0] w_judge;     
    
    // LCD 판정선 감지 신호
    wire w_hit_t1, w_hit_t2;

    // ====================================================
    // 2. 모듈 조립
    // ====================================================

    // (1) 클럭 분주기
    clk_div u_clk_div (
        .clk(clk),
        .rst(rst),
        .o_tick(w_game_tick)
    );

    // (2) 게임 타이머
    game_timer u_game_timer (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .cur_time(w_cur_time)
    );
    
    // (3) 버튼 컨트롤러
    button_ctrl u_btn_ctrl (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .i_btn(i_btn),
        .o_start(w_start_btn), 
        .o_restart(w_restart_btn),
        .o_play(w_play_btn)
    );

    // (4) 악보 FSM
    note_gen u_note_gen (
        .clk(clk),
        .rst(rst),
        .i_cur_time(w_cur_time),
        .o_note_t1(w_note_t1), 
        .o_note_t2(w_note_t2), 
        .o_game_end(w_game_end)
    );
    
    // (5) 피에조 컨트롤러
    piezo_ctrl u_piezo_ctrl (
        .clk(clk), 
        .rst(rst), 
        .i_play_en(w_play_en),     // 판정 모듈에서 받은 신호로 소리 켬
        .i_cnt_limit(w_cnt_limit), // 판정 모듈에서 받은 주파수 재생
        .o_piezo(o_piezo)
    );
    
    // (6) 판정 컨트롤러
    judgement_ctrl u_judge_ctrl (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .i_btn_play(w_play_btn),
        .i_hit_t1(w_hit_t1),     // LCD 감지
        .i_hit_t2(w_hit_t2),
        
        .o_judge(w_judge),
        .o_play_en(w_play_en),   // -> Piezo 켜기
        .o_cnt_limit(w_cnt_limit) // -> Piezo 주파수
    );

    // (7) LCD 컨트롤러
    lcd_ctrl u_lcd_ctrl (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .i_note_t1(w_note_t1),
        .i_note_t2(w_note_t2),
        
        .o_lcd_rs(o_lcd_rs),
        .o_lcd_rw(o_lcd_rw),
        .o_lcd_e(o_lcd_e),
        .o_lcd_data(o_lcd_data),
        
        // 판정 신호 연결
        .o_hit_t1(w_hit_t1), 
        .o_hit_t2(w_hit_t2)
    );

endmodule