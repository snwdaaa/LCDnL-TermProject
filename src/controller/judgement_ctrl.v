module judgement_ctrl (
    input clk,
    input rst,
    input i_tick,           // 1ms 틱 (상태 초기화 타이밍용)
    
    // 입력 신호
    input [1:0] i_btn_play, // [0]: Track 1 버튼, [1]: Track 2 버튼 (채터링 제거됨)

    // LCD 감지 신호들
    input i_hit_t1,      // T1 Perfect Zone
    input i_pre_hit_t1,  // T1 Normal Zone
    input i_miss_t1,     // T1 Miss (떨어짐)
    
    input i_hit_t2,      // T2 Perfect Zone
    input i_pre_hit_t2,  // T2 Normal Zone
    input i_miss_t2,     // T2 Miss (떨어짐)
    
    input [31:0]  i_curr_pitch_t1,
    input [31:0] i_curr_pitch_t2,

    // 출력 신호
    output reg [1:0] o_judge,      // 판정 결과 (00:None, 11:Perfect ...)
    output reg [1:0] o_judge_hold, // [Hold]  디스플레이용 (다음 판정까지 유지) - NEW!
    output reg o_play_en,          // 피에조 켜기
    output reg [31:0] o_cnt_limit, // 피에조 주파수 값
    
    // 노트 삭제 요청 신호
    output reg o_clear_t1_perf,
    output reg o_clear_t1_norm,
    output reg o_clear_t2_perf,
    output reg o_clear_t2_norm
);

    // 소리 지속 시간을 위한 타이머 (100ms)
    reg [31:0] sound_timer;
    parameter SOUND_DURATION = 100; // 100ms 동안 재생

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_judge <= 0; o_judge_hold <= 0;
            o_play_en <= 0; o_cnt_limit <= 0;
            sound_timer <= 0;
            o_clear_t1_perf <= 0; o_clear_t1_norm <= 0;
            o_clear_t2_perf <= 0; o_clear_t2_norm <= 0;
        end else begin
            // Clear 신호는 1클럭만 유지하고 바로 꺼야 함 (Pulse)
            o_clear_t1_perf <= 0; o_clear_t1_norm <= 0;
            o_clear_t2_perf <= 0; o_clear_t2_norm <= 0;

            // ====================================================
            // [Track 1 판정]
            // ====================================================
            if (i_btn_play[0]) begin
                // 1. Perfect (0번 칸)
                if (i_hit_t1) begin
                    o_judge <= 2'b11; o_judge_hold <= 2'b11; // Perfect
                    o_play_en <= 1; o_cnt_limit <= i_curr_pitch_t1;
                    sound_timer <= SOUND_DURATION;
                    o_clear_t1_perf <= 1; // 노트 삭제 요청!
                end
                // 2. Normal (1번 칸) - Perfect가 아닐 때만 체크
                else if (i_pre_hit_t1) begin
                    o_judge <= 2'b10; o_judge_hold <= 2'b10; // Normal
                    o_play_en <= 1; o_cnt_limit <= i_curr_pitch_t1; // (음계는 근사치 사용)
                    sound_timer <= SOUND_DURATION;
                    o_clear_t1_norm <= 1; // 노트 삭제 요청!
                end
            end
            
            // 3. Miss (버튼 안 누르고 지나감)
            if (i_miss_t1) begin
                o_judge <= 2'b01; o_judge_hold <= 2'b01; // Miss
            end


            // ====================================================
            // [Track 2 판정] (위와 동일 구조)
            // ====================================================
            if (i_btn_play[1]) begin
                if (i_hit_t2) begin
                    o_judge <= 2'b11; o_judge_hold <= 2'b11; 
                    o_play_en <= 1; o_cnt_limit <= i_curr_pitch_t2;
                    sound_timer <= SOUND_DURATION;
                    o_clear_t2_perf <= 1;
                end
                else if (i_pre_hit_t2) begin
                    o_judge <= 2'b10; o_judge_hold <= 2'b10; 
                    o_play_en <= 1; o_cnt_limit <= i_curr_pitch_t2;
                    sound_timer <= SOUND_DURATION;
                    o_clear_t2_norm <= 1;
                end
            end
            
            if (i_miss_t2) begin
                o_judge <= 2'b01; o_judge_hold <= 2'b01;
            end

            // ====================================================
            // 상태 초기화
            // ====================================================
            if (i_tick) begin
                o_judge <= 0; // 점수 Pulse 초기화
                if (sound_timer > 0) sound_timer <= sound_timer - 1;
                else o_play_en <= 0;
            end
        end
    end

endmodule