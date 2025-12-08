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

    // Astronomia (Coffin Dance) Frequencies
    localparam F4  = 71586;  // 파 (Main Base)
    localparam C5  = 47778;  // 도 (High)
    localparam A4  = 56818;  // 라
    localparam G4  = 63775;  // 솔
    localparam Bb4 = 53629;  // 시b
    localparam Ab4 = 60197;  // 라b (솔#)
    localparam E4  = 75843;  // 미

    // 노트 개수 설정 (16개 패턴 * 8노트 = 128개)
    parameter NOTE_COUNT = 200;
    integer i, j; // 반복문 변수
    
    // 패턴별 베이스 노트 (첫 2개 음) 저장용 임시 변수
    reg [31:0] base_note;
    
    reg [31:0] note_time  [0:NOTE_COUNT-1];
    reg [1:0]  note_track [0:NOTE_COUNT-1];
    reg [31:0] note_pitch [0:NOTE_COUNT-1];
    
    // 패턴별 시작 시간 계산 (한 패턴당 약 1920ms)
    // idx: 현재 노트 인덱스 (0 ~ 127)
    // time_offset: 현재 패턴의 시작 시간
    integer idx;
    integer time_offset;

    initial begin
        // ==========================================
        // Megalovania (1분 루프 버전)
        // ==========================================
        
        // 전체 4번 반복 (1번 돌 때마다 4가지 패턴 연주)
        for (i = 0; i < 4; i = i + 1) begin
            
            // 4가지 패턴 반복 (D -> C -> B -> Bb)
            for (j = 0; j < 4; j = j + 1) begin
                
                idx = (i * 32) + (j * 8); 
                time_offset = 1000 + (i * 7680) + (j * 1920);

                // 베이스 노트 결정 (패턴마다 앞 2개 음이 다름)
                if      (j == 0) base_note = D4;
                else if (j == 1) base_note = C4;
                else if (j == 2) base_note = B3;
                else             base_note = Bb3;

                // --- [Note 1] 따 (Base) ---
                note_time [idx+0] = time_offset + 0;   note_track[idx+0] = 1; note_pitch[idx+0] = base_note;
                
                // --- [Note 2] 따 (Base) ---
                note_time [idx+1] = time_offset + 120; note_track[idx+1] = 1; note_pitch[idx+1] = base_note; // 빠름!

                // --- [Note 3] 딴 (High D5) ---
                note_time [idx+2] = time_offset + 360; note_track[idx+2] = 2; note_pitch[idx+2] = D5; // 옥타브 점프

                // --- [Note 4] 딴 (A4) ---
                note_time [idx+3] = time_offset + 600; note_track[idx+3] = 2; note_pitch[idx+3] = A4;
                
                // --- [Note 5] 딴 (Ab4) ---
                note_time [idx+4] = time_offset + 840; note_track[idx+4] = 1; note_pitch[idx+4] = Gs4;
                
                // --- [Note 6] 딴 (G4) ---
                note_time [idx+5] = time_offset + 1080; note_track[idx+5] = 2; note_pitch[idx+5] = G4;
                
                // --- [Note 7] 딴 (F4) ---
                note_time [idx+6] = time_offset + 1320; note_track[idx+6] = 1; note_pitch[idx+6] = F4;

                // --- [Note 8] 따다 (D4 F4 G4) - 여기서는 G4로 마무리
                note_time [idx+7] = time_offset + 1560; note_track[idx+7] = 2; note_pitch[idx+7] = G4;
            end
        end
        
        // 마지막 종료 처리
        // note_time[NOTE_COUNT] 처리는 생략 (인덱스 범위 밖)
    end
    
    // 노트가 LCD 끝까지 가는 데 걸리는 시간 (약 5초 여유)
    parameter END_DELAY = 5000;

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
                // 모든 노트 생성 후, 마지막 노트가 판정선에 도착할 때까지 대기
                // ex) 마지막 노트 시간(7700) + 5000ms = 12700ms가 되어야 종료
                if (i_cur_time >= note_time[NOTE_COUNT-1] + END_DELAY) begin
                    o_game_end <= 1;
                end
            end
        end
    end

endmodule