// 노트 생성기
// 현재 게임 시간에 맞춰 악보 데이터 전송 신호 보냄

module note_gen (
    input clk,
    input rst,
    input [31:0] i_cur_time, // game_timer에서 오는 현재 시간 (ms)
    
    output reg o_note_t1,    // Track 1 (윗줄) 노트 생성 신호 (1틱 동안 1)
    output reg o_note_t2,    // Track 2 (아랫줄) 노트 생성 신호
    output reg [31:0] o_gen_pitch, // 생성된 노트의 주파수 값
    output reg o_game_end    // 노래가 끝났음을 알리는 신호
);

    // ==========================================
    // 악보 데이터 하드코딩
    // ==========================================
    
    reg [31:0] note_time [0:NOTE_COUNT-1]; // 시간 저장
    reg [1:0]  note_track [0:NOTE_COUNT-1]; // 트랙 저장 (1:윗줄, 2:아랫줄, 3:동시)
    reg [31:0] note_pitch [0:NOTE_COUNT-1]; // 음계 저장 배열

// ==========================================
    // ? Smoke on the Water (Intro Riff)
    // ==========================================
    
    // 1. 주파수 상수 정의 (50MHz 클럭 기준 카운터 값)
    // 공식: 50,000,000 / (주파수 * 2)
    localparam G3  = 127551; // 솔 (196 Hz)
    localparam Bb3 = 107296; // 시b (233 Hz)
    localparam C4  = 95556;  // 도 (262 Hz)
    localparam Db4 = 90197;  // 레b (277 Hz) - 6번 프렛

    // 노트 개수 (총 12개 노트로 구성된 리프)
    parameter NOTE_COUNT = 12;
    
    reg [31:0] note_time  [0:NOTE_COUNT-1];
    reg [1:0]  note_track [0:NOTE_COUNT-1];
    reg [31:0] note_pitch [0:NOTE_COUNT-1];

    initial begin
        // BPM 112 기준: 4분음표(1박) ? 536ms, 8분음표(반박) ? 268ms
        // 시작 시간: 1000ms (1초 대기 후 시작)

        // --- [Part 1] 0 - 3 - 5 ---
        note_time[0] = 1000;       note_track[0] = 2; note_pitch[0] = G3;  // 아랫줄
        note_time[1] = 1536;       note_track[1] = 1; note_pitch[1] = Bb3; // 윗줄
        note_time[2] = 2072;       note_track[2] = 2; note_pitch[2] = C4;  // 아랫줄

        // --- [Part 2] 0 - 3 - 6 - 5 --- 
        // (여기가 5번, 6번 노트 구간입니다!)
        note_time[3] = 3144;       note_track[3] = 1; note_pitch[3] = G3;  // 윗줄
        note_time[4] = 3680;       note_track[4] = 2; note_pitch[4] = Bb3; // 아랫줄
        
        // [수정] 5번, 6번이 겹치지 않게 확실히 분리!
        note_time[5] = 4216;       note_track[5] = 1; note_pitch[5] = Db4; // 윗줄 ("빠")
        note_time[6] = 4752;       note_track[6] = 2; note_pitch[6] = C4;  // 아랫줄 ("빠~")

        // --- [Part 3] 0 - 3 - 5 - 3 - 0 ---
        note_time[7] = 5556;       note_track[7] = 1; note_pitch[7] = G3;  // 윗줄
        note_time[8] = 6092;       note_track[8] = 2; note_pitch[8] = Bb3; // 아랫줄
        note_time[9] = 6628;       note_track[9] = 1; note_pitch[9] = C4;  // 윗줄
        note_time[10] = 7164;      note_track[10] = 2; note_pitch[10] = Bb3; // 아랫줄
        note_time[11] = 7700;      note_track[11] = 1; note_pitch[11] = G3;  // 윗줄
    end

    // ==========================================
    // 시퀀서 로직 (FSM)
    // ==========================================
    reg [31:0] note_idx; // 현재 몇 번째 노트를 기다리는 중인지 (포인터)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            note_idx <= 0;
            o_note_t1 <= 0;
            o_note_t2 <= 0;
            o_gen_pitch <= 0;
            o_game_end <= 0;
        end else begin
            o_note_t1 <= 0;
            o_note_t2 <= 0;

            // 노래가 아직 안 끝났다면
            if (note_idx < NOTE_COUNT) begin
                // 현재 시간이 노트의 시간과 같거나 지났으면? (놓쳤을 경우 대비 >= 사용)
                if (i_cur_time >= note_time[note_idx]) begin
                    // 음계 정보 출력
                    o_gen_pitch <= note_pitch[note_idx];
                    
                    // 해당 트랙에 신호 발사
                    if (note_track[note_idx] == 1) 
                        o_note_t1 <= 1;
                    
                    if (note_track[note_idx] == 2) 
                        o_note_t2 <= 1;

                    // 다음 노트로 포인터 이동
                    note_idx <= note_idx + 1;
                end
            end else begin
                // 모든 노트를 다 보냈으면 게임 종료 신호
                // (마지막 노트 보내고 조금 뒤에 끝내고 싶으면 여기서 시간 체크를 더 해도 됨)
                o_game_end <= 1;
            end
        end
    end

endmodule