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
    
    // 풀컬러 LED 출력 포트
    output [3:0] o_fcl_r, 
    output [3:0] o_fcl_g, 
    output [3:0] o_fcl_b,
    
    // 단일 7-Segment용 출력 핀 (Single)
    output [7:0] o_single_seg, 

    // 8-Array Segment용 출력 핀 (Array)
    output [7:0] o_array_seg, // a~g, dp 패턴
    output [7:0] o_array_com, // Digit Select
    
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
    
    wire [31:0] w_gen_pitch;        // note_gen -> lcd_ctrl
    wire [31:0] w_curr_pitch_t1;    // lcd_ctrl -> logic
    wire [31:0] w_curr_pitch_t2;    // lcd_ctrl -> logic
    
    // 모듈 간 연결을 위한 신호선 (Wire)
    wire [1:0] w_judge;         // 판정 결과 (Judge -> Score, LED)
    wire [15:0] w_total_score;  // 계산된 점수 (Score -> 7-Segment)

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
        .o_game_end(w_game_end),
        .o_gen_pitch(w_gen_pitch)   // [연결] 생성된 음계
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
        .o_hit_t2(w_hit_t2),
        
        .i_gen_pitch(w_gen_pitch),      // [연결] 음계 받아서 운반
        .o_curr_pitch_t1(w_curr_pitch_t1), // [연결] 배달 완료된 음계
        .o_curr_pitch_t2(w_curr_pitch_t2)
    );
    
    // 판정 컨트롤러
    judgement_ctrl u_judge_ctrl (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .i_btn_play(w_play_btn),
        .i_hit_t1(w_hit_t1),     // LCD 감지
        .i_hit_t2(w_hit_t2),
        .i_curr_pitch_t1(w_curr_pitch_t1),
        .i_curr_pitch_t2(w_curr_pitch_t2),
        
        .o_judge(w_judge),
        .o_play_en(w_play_en),   // -> Piezo 켜기
        .o_cnt_limit(w_cnt_limit) // -> Piezo 주파수
    );
    
    // 점수 모듈
    score_ctrl u_score_ctrl (
        .clk(clk),
        .rst(rst),
        .i_judge(w_judge),      // [입력] 판정 결과를 받아서
        .o_score(w_total_score) // [출력] 누적 점수를 계산해 보냄
    );

    // Full Color LED
    full_color_led_ctrl u_led_ctrl (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .i_game_over(w_game_end),
        .i_judge(w_judge),      // [입력] 판정 결과를 받아서 색상 표현
        .o_fcl_r(o_fcl_r),
        .o_fcl_g(o_fcl_g),
        .o_fcl_b(o_fcl_b)
    );

    // 단일 7-Segment 컨트롤러 (판정 점수 2,1,0 표시)
    seven_segment_ctrl u_single_seg (
        .i_judge(w_judge),      // 판정 결과 입력
        .o_seg(o_single_seg)    // -> 단일 세그먼트 핀으로 출력
    );

    // 8-Array Segment 컨트롤러 (텍스트 + 누적 점수)
    eight_array_seven_segment_ctrl u_array_seg (
        .clk(clk),
        .rst(rst),
        .i_judge(w_judge),       // 텍스트 표시용
        .i_data(w_total_score),  // 점수 표시용
        .o_seg(o_array_seg),     // -> 어레이 세그먼트 패턴 핀
        .o_com(o_array_com)      // -> 어레이 공통 핀
    );
    
    // (5) 피에조 컨트롤러
    piezo_ctrl u_piezo_ctrl (
        .clk(clk), 
        .rst(rst), 
        .i_play_en(w_play_en),     // 판정 모듈에서 받은 신호로 소리 켬
        .i_cnt_limit(w_cnt_limit), // 판정 모듈에서 받은 주파수 재생
        .o_piezo(o_piezo)
    );

endmodule