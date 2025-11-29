// 노트 생성기
// 현재 게임 시간에 맞춰 악보 데이터 전송 신호 보냄

module note_gen (
    input clk,
    input rst,
    input [31:0] i_cur_time, // game_timer에서 오는 현재 시간 (ms)
    
    output reg o_note_t1,    // Track 1 (윗줄) 노트 생성 신호 (1틱 동안 1)
    output reg o_note_t2,    // Track 2 (아랫줄) 노트 생성 신호
    output reg o_game_end    // 노래가 끝났음을 알리는 신호
);

    // ==========================================
    // 악보 데이터 하드코딩
    // ==========================================
    // 노트 개수
    parameter NOTE_COUNT = 10;
    
    reg [31:0] note_time [0:NOTE_COUNT-1]; // 시간 저장
    reg [1:0]  note_track [0:NOTE_COUNT-1]; // 트랙 저장 (1:윗줄, 2:아랫줄, 3:동시)

    initial begin
        // {시간(ms), 트랙}
        // LCD 오른쪽 끝에서 왼쪽 판정선까지 오는데 걸리는 시간을 고려해서 배치
        // 예: 스크롤 속도가 빠르다면, 판정하고 싶은 시간보다 조금 일찍 생성해야 함
        
        // 일단은 '생성 시간' 기준으로 작성해 봅시다.
        note_time[0] = 1000; note_track[0] = 1; // 1초: 윗줄
        note_time[1] = 2000; note_track[1] = 2; // 2초: 아랫줄
        note_time[2] = 2500; note_track[2] = 1; 
        note_time[3] = 3000; note_track[3] = 2;
        note_time[4] = 3500; note_track[4] = 1;
        note_time[5] = 4000; note_track[5] = 3; // 4초: 동시 치기!
        note_time[6] = 5000; note_track[6] = 1;
        note_time[7] = 5500; note_track[7] = 2;
        note_time[8] = 6000; note_track[8] = 1;
        note_time[9] = 7000; note_track[9] = 3; // 마지막 동시 치기
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
            o_game_end <= 0;
        end else begin
            o_note_t1 <= 0;
            o_note_t2 <= 0;

            // 노래가 아직 안 끝났다면
            if (note_idx < NOTE_COUNT) begin
                // 현재 시간이 노트의 시간과 같거나 지났으면? (놓쳤을 경우 대비 >= 사용)
                if (i_cur_time >= note_time[note_idx]) begin
                    
                    // 해당 트랙에 신호 발사
                    if (note_track[note_idx] == 1 || note_track[note_idx] == 3) 
                        o_note_t1 <= 1;
                    
                    if (note_track[note_idx] == 2 || note_track[note_idx] == 3) 
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