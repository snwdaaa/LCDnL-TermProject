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
    input [3:0] i_btn,       // 버튼 입력 4개
    
    // 8개 LED 출력 포트
    output [7:0] o_led
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
//    wire w_play_en;         // 소리 재생 Enable
//    wire [31:0] w_cnt_limit;// 재생할 주파수 값

    // 소리 관련 와이어 이름 구분
    wire w_game_play_en;      // 게임 중 판정 소리 (from Judge)
    wire [31:0] w_game_pitch; // 게임 중 판정 주파수 (from Judge)

    wire w_intro_play_en;     // 인트로 소리 (from Intro Player)
    wire [31:0] w_intro_pitch;// 인트로 주파수 (from Intro Player)
    
    wire w_final_piezo_en;    // 최종 피에조 입력
    wire [31:0] w_final_pitch;// 최종 피에조 주파수
    
    // 판정 결과 신호 (현재 사용 안 함, 추후 확장용)
    wire [1:0] w_judge;     
    
    // LCD 판정선 감지 신호
    wire w_hit_t1, w_hit_t2;
    
    wire [31:0] w_gen_pitch;        // note_gen -> lcd_ctrl
    wire [31:0] w_curr_pitch_t1;    // lcd_ctrl -> logic
    wire [31:0] w_curr_pitch_t2;    // lcd_ctrl -> logic
    
    // 모듈 간 연결을 위한 신호선 (Wire)
    wire [1:0] w_judge;         // 판정 결과 (Judge -> Score, LED)
    wire [1:0] w_judge_hold;
    wire [15:0] w_total_score;  // 계산된 점수 (Score -> 7-Segment)
    
    wire w_hit_t1, w_pre_hit_t1, w_miss_t1;
    wire w_hit_t2, w_pre_hit_t2, w_miss_t2;
    wire w_clr_t1_perf, w_clr_t1_norm;
    wire w_clr_t2_perf, w_clr_t2_norm;
    
    // 게임 시작 상태를 저장할 레지스터
    reg r_game_start;
    reg r_game_end;
    
    // "게임 시작 전" 또는 "게임 종료 후"에 켜지도록 OR 연산 추가
    wire w_siren_on = (~r_game_start) || r_game_end;
    
    // [추가] 시작 버튼 누르면 게임 시작 상태로 변경
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_game_start <= 0;
        end else begin
            if (w_start_btn) begin // 버튼 컨트롤러에서 온 시작 신호
                r_game_start <= 1;
            end
        end
    end

    // [중요] 게임이 시작되었을 때만 시간이 흐르도록 Tick 신호를 제어
    // r_game_start가 1일 때만 w_game_tick이 타이머로 전달됨
    wire w_gated_tick;
    assign w_gated_tick = w_game_tick && r_game_start;

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
        .i_tick(w_gated_tick),
        .cur_time(w_cur_time)
    );
    
    intro_player u_intro_player (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),        // 1ms 틱 (gated 아님! 계속 흘러야 함)
        .i_enable(w_siren_on),    // 게임 시작 전(0)일 때만 동작
        .o_play_en(w_intro_play_en),
        .o_pitch(w_intro_pitch)
    );
    
    // 게임 시작 전이면 intro 소리, 시작 후면 game 소리 연결
    assign w_final_piezo_en = (r_game_start) ? w_game_play_en : w_intro_play_en;
    assign w_final_pitch    = (r_game_start) ? w_game_pitch   : w_intro_pitch;
    
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
        
        .i_gen_pitch(w_gen_pitch),      // [연결] 음계 받아서 운반
        .o_curr_pitch_t1(w_curr_pitch_t1), // [연결] 배달 완료된 음계
        .o_curr_pitch_t2(w_curr_pitch_t2),
        
        // 입력: 삭제 요청 받기
        .i_clear_t1_perf(w_clr_t1_perf),
        .i_clear_t1_norm(w_clr_t1_norm),
        .i_clear_t2_perf(w_clr_t2_perf),
        .i_clear_t2_norm(w_clr_t2_norm),
        
        // 출력: 상황 보고
        .o_hit_t1(w_hit_t1),
        .o_pre_hit_t1(w_pre_hit_t1),
        .o_miss_t1(w_miss_t1),
        .o_hit_t2(w_hit_t2),
        .o_pre_hit_t2(w_pre_hit_t2),
        .o_miss_t2(w_miss_t2),
        
        .i_game_start(r_game_start),
        .i_game_over(w_game_end) // note_gen에서 나온 종료 신호
    );
    
    // 판정 컨트롤러
    judgement_ctrl u_judge_ctrl (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),
        .i_btn_play(w_play_btn),
        .i_hit_t1(w_hit_t1), .i_pre_hit_t1(w_pre_hit_t1), .i_miss_t1(w_miss_t1),
        .i_hit_t2(w_hit_t2), .i_pre_hit_t2(w_pre_hit_t2), .i_miss_t2(w_miss_t2),
        .i_curr_pitch_t1(w_curr_pitch_t1),
        .i_curr_pitch_t2(w_curr_pitch_t2),
        
        .o_judge(w_judge),
        .o_judge_hold(w_judge_hold),
        .o_play_en(w_game_play_en),   // -> Piezo 켜기
        .o_cnt_limit(w_game_pitch), // -> Piezo 주파수
        
        // 출력: 노트 삭제 요청
        .o_clear_t1_perf(w_clr_t1_perf), .o_clear_t1_norm(w_clr_t1_norm),
        .o_clear_t2_perf(w_clr_t2_perf), .o_clear_t2_norm(w_clr_t2_norm)
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
        .i_judge(w_judge_hold),      // [입력] 판정 결과를 받아서 색상 표현
        .o_fcl_r(o_fcl_r),
        .o_fcl_g(o_fcl_g),
        .o_fcl_b(o_fcl_b)
    );

    // 단일 7-Segment 컨트롤러 (판정 점수 2,1,0 표시)
    seven_segment_ctrl u_single_seg (
        .i_judge(w_judge_hold),      // 판정 결과 입력
        .o_seg(o_single_seg)    // -> 단일 세그먼트 핀으로 출력
    );

    // 8-Array Segment 컨트롤러 (텍스트 + 누적 점수)
    eight_array_seven_segment_ctrl u_array_seg (
        .clk(clk),
        .rst(rst),
        .i_judge(w_judge_hold),       // 텍스트 표시용
        .i_data(w_total_score),  // 점수 표시용
        .o_seg(o_array_seg),     // -> 어레이 세그먼트 패턴 핀
        .o_com(o_array_com)      // -> 어레이 공통 핀
    );
    
    // (5) 피에조 컨트롤러
    piezo_ctrl u_piezo_ctrl (
        .clk(clk), 
        .rst(rst), 
        .i_play_en(w_final_piezo_en),     // 판정 모듈에서 받은 신호로 소리 켬
        .i_cnt_limit(w_final_pitch), // 판정 모듈에서 받은 주파수 재생
        .o_piezo(o_piezo)
    );
    
    // LED 컨트롤러 
    led_ctrl u_discrete_led_ctrl (
        .clk(clk),
        .rst(rst),
        .i_tick(w_game_tick),      // 1ms 틱 연결
        .i_game_start(r_game_start), // 게임 시작 신호 (이전 단계에서 만듬)
        .i_game_over(w_game_end),    // 게임 종료 신호
        .o_led(o_led)              // -> [출력] 보드 핀으로 연결
    );

endmodule