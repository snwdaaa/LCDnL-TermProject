module judgement_ctrl (
    input clk,
    input rst,
    input i_tick,           // 1ms 틱 (상태 초기화 타이밍용)
    
    // 입력 신호
    input [1:0] i_btn_play, // [0]: Track 1 버튼, [1]: Track 2 버튼 (채터링 제거됨)
    input i_hit_t1,         // Track 1 판정선 감지 (LCD에서 옴)
    input i_hit_t2,         // Track 2 판정선 감지 (LCD에서 옴)
    
    input [31:0]  i_curr_pitch_t1,
    input [31:0] i_curr_pitch_t2,

    // 출력 신호
    output reg [1:0] o_judge,      // 판정 결과 (00:None, 11:Perfect ...)
    output reg o_play_en,          // 피에조 켜기
    output reg [31:0] o_cnt_limit // 피에조 주파수 값
);

    // 소리 지속 시간을 위한 타이머 (100ms)
    reg [31:0] sound_timer;
    parameter SOUND_DURATION = 100; // 100ms 동안 재생

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_judge <= 0;
            o_play_en <= 0;
            o_cnt_limit <= 0;
            sound_timer <= 0;
        end else begin
            // ====================================================
            // 1. 판정 수행 (Priority: Track 1 -> Track 2)
            // ====================================================
            
            // [Track 1 성공?] LCD에 노트 있고(i_hit_t1) & 버튼 눌렀을 때(i_btn_play[0])
            if (i_hit_t1 && i_btn_play[0]) begin
                o_judge <= 2'b11;        // Perfect!
                o_play_en <= 1;          // 소리 ON
                o_cnt_limit <= i_curr_pitch_t1;  // LCD로부터 받은 음계 재생
                sound_timer <= SOUND_DURATION;  // 타이머 충전
            end
            
            // [Track 2 성공?]
            if (i_hit_t2 && i_btn_play[1]) begin
                o_judge <= 2'b11;        // Perfect!
                o_play_en <= 1;          // 소리 ON
                o_cnt_limit <= i_curr_pitch_t2;  // LCD로부터 받은 음계 재생
                sound_timer <= SOUND_DURATION;  // 타이머 충전
            end
            
            // ====================================================
            // 2. 상태 초기화 (Auto Reset)
            // ====================================================
            else begin
                // 1ms 틱이 지날 때마다 판정 상태를 초기화합니다.
                // (이렇게 안 하면 Perfect가 영원히 유지될 수 있음)
                if (i_tick) begin
                    o_judge <= 0;       // IDLE 상태로 복귀
  
                    // 소리 자동 끄기 로직
                    if (sound_timer > 0) begin
                        sound_timer <= sound_timer - 1;
                    end else begin
                        o_play_en <= 0; // 시간이 다 되면 소리 끄기
                    end
                end
            end
        end
    end

endmodule