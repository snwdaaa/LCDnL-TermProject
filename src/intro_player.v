module intro_player (
    input clk,
    input rst,
    input i_tick,          // 1ms 틱
    input i_enable,        // 1일 때만 소리 재생 (게임 시작 전)
    
    output reg o_play_en,      // 피에조 켜기/끄기
    output reg [31:0] o_pitch  // 피에조 주파수 값 (Counter Limit)
);

    // ==========================================
    // "Sweet Child O' Mine" Riff Frequencies
    // 공식: 50MHz / (Freq * 2)
    // ==========================================
    localparam D4  = 85132; // 293.66 Hz
    localparam D5  = 42565; // 587.33 Hz
    localparam A4  = 56818; // 440.00 Hz
    localparam G4  = 63775; // 392.00 Hz
    localparam G5  = 31888; // 783.99 Hz
    localparam Fs5  = 33784; // 739.99 Hz (F#5)

    // 리프 노트 순서 (8개 반복)
    // Pattern: D4 -> D5 -> A4 -> G4 -> G5 -> A4 -> F#5 -> A4
    reg [31:0] riff_pitch [0:7];
    initial begin
        riff_pitch[0] = D4;
        riff_pitch[1] = D5;
        riff_pitch[2] = A4;
        riff_pitch[3] = G4;
        riff_pitch[4] = G5;
        riff_pitch[5] = A4;
        riff_pitch[6] = Fs5;
        riff_pitch[7] = A4;
    end

    // 타이밍 설정
    parameter NOTE_DURATION = 200; // 한 음당 200ms (템포 조절 가능)
    
    reg [31:0] time_cnt;
    reg [2:0]  note_idx; // 0~7

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            time_cnt <= 0;
            note_idx <= 0;
            o_play_en <= 0;
            o_pitch <= 0;
        end 
        else if (i_enable) begin
            // 소리 켜기
            o_play_en <= 1;
            o_pitch <= riff_pitch[note_idx];

            // 타이머 동작
            if (i_tick) begin
                if (time_cnt >= NOTE_DURATION - 1) begin
                    time_cnt <= 0;
                    note_idx <= note_idx + 1; // 다음 노트 (자동으로 0~7 오버플로우)
                end 
                else begin
                    time_cnt <= time_cnt + 1;
                end
            end
        end 
        else begin
            // 비활성화 시 초기화
            o_play_en <= 0;
            o_pitch <= 0;
            time_cnt <= 0;
            note_idx <= 0;
        end
    end

endmodule