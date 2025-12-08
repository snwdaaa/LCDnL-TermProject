module lcd_ctrl (
    input clk,              // 시스템 클럭 (50MHz)
    input rst,              // 리셋
    input i_tick,           // 1ms 틱 (스크롤 속도 조절용)
    
    // 노트 생성 신호 (from note_gen)
    input i_note_t1,        // 윗줄 (Track 1) 노트
    input i_note_t2,        // 아랫줄 (Track 2) 노트
    
    input [31:0] i_gen_pitch, // note_gen에서 받은 음계
    
    // [NEW] 판정 성공 시 노트를 지우기 위한 입력 신호
    input i_clear_t1_perf, // Track 1 Perfect 위치(0번) 지워라
    input i_clear_t1_norm, // Track 1 Normal 위치(1번) 지워라
    input i_clear_t2_perf,
    input i_clear_t2_norm,
    
    // 게임 상태 신호
    input i_game_start, // 0: 대기 화면, 1: 게임 진행
    input i_game_over,  // 0: 진행 중, 1: 게임 종료
    
    // LCD 하드웨어 핀 (보드 핀에 연결)
    output reg o_lcd_rs,    // 0:명령, 1:데이터
    output reg o_lcd_rw,    // 0:쓰기, 1:읽기 (항상 0)
    output reg o_lcd_e,     // Enable 펄스
    output reg [7:0] o_lcd_data, // 데이터 버스
    
    // [NEW] 판정 관련 상태 알림 신호
    output o_hit_t1,      // [0번 칸] Perfect 존 감지
    output o_pre_hit_t1,  // [1번 칸] Normal 존 감지
    output o_hit_t2,      
    output o_pre_hit_t2,  
    
    // [NEW] 놓침(Miss) 알림 신호
    output reg o_miss_t1, 
    output reg o_miss_t2,
    
    // 현재 판정선에 있는 노트의 음계 값
    output reg [31:0] o_curr_pitch_t1, 
    output reg [31:0] o_curr_pitch_t2
);

    // ====================================================
    // [Part 1] 노트 스크롤링 및 버퍼 관리 로직
    // ====================================================
    
    // 1. 화면 버퍼 (16칸 x 2줄)
    reg [7:0] line1 [0:15]; // 윗줄
    reg [7:0] line2 [0:15]; // 아랫줄
    
    // 음계 버퍼
    reg [31:0] pitch_buf_t1 [0:15];
    reg [31:0] pitch_buf_t2 [0:15];

    // 2. 노트 캡처 (Note Capture)
    reg r_catch_t1, r_catch_t2;
    reg [31:0] r_catch_pitch;

    // 3. 스크롤 타이머 (Scroll Timer)
    parameter SCROLL_SPEED = 300; 
    reg [31:0] scroll_cnt;
    wire scroll_en;

    always @(posedge clk or posedge rst) begin
        if (rst) scroll_cnt <= 0;
        else if (i_tick) begin
            if (scroll_cnt >= SCROLL_SPEED - 1) scroll_cnt <= 0;
            else scroll_cnt <= scroll_cnt + 1;
        end
    end
    assign scroll_en = (i_tick && (scroll_cnt == 0));

    // 4. 버퍼 업데이트 (핵심 로직: 이동, Miss, Clear)
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 리셋 시 "Press Start..." 문구로 초기화
            // "Press Start Btn " (16글자)
            line1[0]<="P"; line1[1]<="r"; line1[2]<="e"; line1[3]<="s"; 
            line1[4]<="s"; line1[5]<=" "; line1[6]<="S"; line1[7]<="t"; 
            line1[8]<="a"; line1[9]<="r"; line1[10]<="t"; line1[11]<=" "; 
            line1[12]<="B"; line1[13]<="t"; line1[14]<="n"; line1[15]<=" ";
            
            // 초기화
            for (i=0; i<16; i=i+1) begin
                line2[i] <= 8'h20; // 아랫줄 공백    
                pitch_buf_t1[i] <= 0; pitch_buf_t2[i] <= 0;
            end
            r_catch_t1 <= 0; r_catch_t2 <= 0; r_catch_pitch <= 0;
            o_miss_t1 <= 0; o_miss_t2 <= 0;
        end
        else begin
            // (1) 우선순위 1: 게임 오버 화면
            if (i_game_over) begin
                // "   Game Over!   "
                line1[0]<=" "; line1[1]<=" "; line1[2]<=" "; line1[3]<="G"; 
                line1[4]<="a"; line1[5]<="m"; line1[6]<="e"; line1[7]<=" "; 
                line1[8]<="O"; line1[9]<="v"; line1[10]<="e"; line1[11]<="r"; 
                line1[12]<="!"; line1[13]<=" "; line1[14]<=" "; line1[15]<=" ";
                
                for (i=0; i<16; i=i+1) begin
                    line2[i] <= 8'h20; // 아랫줄 공백 
                end
            end
            // (2) 우선순위 2: 게임 대기 화면 (시작 전)
            else if (i_game_start == 0) begin
                // 리셋과 동일하게 "Press Start Btn " 유지
                line1[0]<="P"; line1[1]<="r"; line1[2]<="e"; line1[3]<="s"; 
                line1[4]<="s"; line1[5]<=" "; line1[6]<="S"; line1[7]<="t"; 
                line1[8]<="a"; line1[9]<="r"; line1[10]<="t"; line1[11]<=" "; 
                line1[12]<="B"; line1[13]<="t"; line1[14]<="n"; line1[15]<=" ";
            end        
            // (3) 우선순위 3: 게임 플레이 (기존 스크롤 로직)
            
            else begin
                // (1) Miss 감지 플래그 초기화 (매 클럭마다 리셋)
                o_miss_t1 <= 0; 
                o_miss_t2 <= 0;
    
                // (2) 스크롤 동작 (Shift)
                if (scroll_en) begin
                    // 이동하기 전에 맨 끝(0번)에 노트가 있었으면 -> Miss 발생!
                    if (line1[0] == 8'h4F) o_miss_t1 <= 1;
                    if (line2[0] == 8'h4F) o_miss_t2 <= 1;
    
                    // [왼쪽으로 이동]
                    for (i=0; i<15; i=i+1) begin
                        line1[i] <= line1[i+1];
                        line2[i] <= line2[i+1];
                        pitch_buf_t1[i] <= pitch_buf_t1[i+1];
                        pitch_buf_t2[i] <= pitch_buf_t2[i+1];
                    end
                    
                    // [오른쪽 끝 채우기]
                    line1[15] <= (r_catch_t1) ? 8'h4F : 8'h20;
                    line2[15] <= (r_catch_t2) ? 8'h4F : 8'h20;
                    pitch_buf_t1[15] <= (r_catch_t1) ? r_catch_pitch : 0;
                    pitch_buf_t2[15] <= (r_catch_t2) ? r_catch_pitch : 0;
                    
                    // 캡처 초기화
                    r_catch_t1 <= 0; r_catch_t2 <= 0;
                end 
                else begin
                    // 스크롤이 아닐 때: 새 노트 캡처
                    if (i_note_t1) begin r_catch_t1 <= 1; r_catch_pitch <= i_gen_pitch; end
                    if (i_note_t2) begin r_catch_t2 <= 1; r_catch_pitch <= i_gen_pitch; end
                end
    
                // (3) [NEW] 노트 지우기 (Clear Note) - 판정 성공 시 실행
                // Judgement 모듈에서 요청이 오면 해당 칸을 공백으로 덮어씀
                
                // Track 1 Clear
                if (i_clear_t1_perf) begin line1[0] <= 8'h20; pitch_buf_t1[0] <= 0; end
                if (i_clear_t1_norm) begin line1[1] <= 8'h20; pitch_buf_t1[1] <= 0; end
                
                // Track 2 Clear
                if (i_clear_t2_perf) begin line2[0] <= 8'h20; pitch_buf_t2[0] <= 0; end
                if (i_clear_t2_norm) begin line2[1] <= 8'h20; pitch_buf_t2[1] <= 0; end
            end
        end
    end
    
    // ====================================================
    // [Part 3] 판정 관련 신호 출력
    // ====================================================
    // 'O' (0x4F) 문자가 있는지 확인
    assign o_hit_t1     = (line1[0] == 8'h4F); // 0번 칸 (Perfect)
    assign o_pre_hit_t1 = (line1[1] == 8'h4F); // 1번 칸 (Normal)
    
    assign o_hit_t2     = (line2[0] == 8'h4F);
    assign o_pre_hit_t2 = (line2[1] == 8'h4F);
    
    // 음계 출력 수정: Perfect(0번) 또는 Normal(1번) 위치의 음계 값을 전달
    always @(*) begin
        // [Track 1]
        if (pitch_buf_t1[0] > 0)       
            o_curr_pitch_t1 = pitch_buf_t1[0]; // 0번에 노트가 있으면 1순위 (Perfect)
        else if (pitch_buf_t1[1] > 0)  
            o_curr_pitch_t1 = pitch_buf_t1[1]; // 1번에 노트가 있으면 2순위 (Normal)
        else                           
            o_curr_pitch_t1 = 0;               // 둘 다 없으면 0

        // [Track 2]
        if (pitch_buf_t2[0] > 0)       
            o_curr_pitch_t2 = pitch_buf_t2[0];
        else if (pitch_buf_t2[1] > 0)  
            o_curr_pitch_t2 = pitch_buf_t2[1];
        else                           
            o_curr_pitch_t2 = 0;
    end

    // ====================================================
    // [Part 2] LCD 드라이버 (Hardware Control FSM) - 기존 유지
    // ====================================================
    
    // 상태 정의
    localparam S_INIT       = 0;
    localparam S_CMD_PRE    = 1;
    localparam S_CMD_SEND   = 2;
    localparam S_CMD_HOLD   = 3;
    localparam S_DATA_PRE   = 4;
    localparam S_DATA_SEND  = 5;
    localparam S_DATA_HOLD  = 6;
    
    reg [3:0] state;
    reg [4:0] init_step;
    reg [4:0] char_idx;
    reg [31:0] delay_cnt;
    
    parameter DLY_2MS = 100000;
    parameter DLY_50US = 2500;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_INIT;
            init_step <= 0;
            char_idx <= 0;
            delay_cnt <= 0;
            o_lcd_e <= 0;
            o_lcd_rs <= 0;
            o_lcd_rw <= 0;
            o_lcd_data <= 0;
        end else begin
            case (state)
                S_INIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt > DLY_2MS * 10) begin 
                        delay_cnt <= 0;
                        state <= S_CMD_PRE;
                    end
                end

                S_CMD_PRE: begin
                    o_lcd_rs <= 0; 
                    o_lcd_rw <= 0; 
                    o_lcd_e  <= 0;
                    case (init_step)
                        0: o_lcd_data <= 8'h38;
                        1: o_lcd_data <= 8'h0C;
                        2: o_lcd_data <= 8'h06;
                        3: o_lcd_data <= 8'h01;
                        4: o_lcd_data <= 8'h80;
                        5: o_lcd_data <= 8'hC0;
                        default: o_lcd_data <= 8'h80;
                    endcase
                    state <= S_CMD_SEND;
                end

                S_CMD_SEND: begin
                    o_lcd_e <= 1;
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt > 50) begin 
                        delay_cnt <= 0;
                        state <= S_CMD_HOLD;
                    end
                end
                
                S_CMD_HOLD: begin
                    o_lcd_e <= 0;
                    delay_cnt <= delay_cnt + 1;
                    if ((init_step == 3 && delay_cnt > DLY_2MS) || 
                        (init_step != 3 && delay_cnt > DLY_50US)) begin
                        delay_cnt <= 0;
                        if (init_step < 4) begin
                            init_step <= init_step + 1;
                            state <= S_CMD_PRE;
                        end else begin
                            if (init_step == 4) begin
                                char_idx <= 0;
                                state <= S_DATA_PRE; 
                            end else if (init_step == 5) begin
                                char_idx <= 16;
                                state <= S_DATA_PRE;
                            end
                        end
                    end
                end

                S_DATA_PRE: begin
                    o_lcd_rs <= 1; 
                    o_lcd_rw <= 0;
                    o_lcd_e  <= 0;
                    if (char_idx < 16) 
                        o_lcd_data <= line1[char_idx];
                    else 
                        o_lcd_data <= line2[char_idx - 16];
                    state <= S_DATA_SEND;
                end

                S_DATA_SEND: begin
                    o_lcd_e <= 1;
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt > 50) begin
                        delay_cnt <= 0;
                        state <= S_DATA_HOLD;
                    end
                end

                S_DATA_HOLD: begin
                    o_lcd_e <= 0;
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt > DLY_50US) begin
                        delay_cnt <= 0;
                        if (char_idx == 15) begin
                            init_step <= 5; 
                            state <= S_CMD_PRE;
                        end else if (char_idx == 31) begin
                            init_step <= 4; 
                            state <= S_CMD_PRE;
                        end else begin
                            char_idx <= char_idx + 1;
                            state <= S_DATA_PRE;
                        end
                    end
                end
            endcase
        end
    end

endmodule