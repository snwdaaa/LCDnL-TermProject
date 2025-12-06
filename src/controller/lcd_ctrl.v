module lcd_ctrl (
    input clk,              // 시스템 클럭 (50MHz)
    input rst,              // 리셋
    input i_tick,           // 1ms 틱 (스크롤 속도 조절용)
    
    // 노트 생성 신호 (from note_gen)
    // 1클럭 동안만 '반짝'하므로 놓치지 않고 잡아야 합니다.
    input i_note_t1,        // 윗줄 (Track 1) 노트
    input i_note_t2,        // 아랫줄 (Track 2) 노트
    
    input [31:0] i_gen_pitch, // note_gen에서 받은 음계
    
    // 판정 성공 시 노트를 지우기 위한 신호
    input i_clear_t1_perf, // Track 1 Perfect 위치(0번) 지워라
    input i_clear_t1_norm, // Track 1 Normal 위치(1번) 지워라
    input i_clear_t2_perf,
    input i_clear_t2_norm,
    
    // LCD 하드웨어 핀 (보드 핀에 연결)
    output reg o_lcd_rs,    // 0:명령, 1:데이터
    output reg o_lcd_rw,    // 0:쓰기, 1:읽기 (항상 0)
    output reg o_lcd_e,     // Enable 펄스
    output reg [7:0] o_lcd_data, // 데이터 버스
    
    // 판정용 상태 신호
    output o_hit_t1,      // [0번 칸] Perfect 존 감지
    output o_pre_hit_t1,  // [1번 칸] Normal 존 감지 - NEW!
    output o_hit_t2,      
    output o_pre_hit_t2,  
    
    // 놓침(Miss) 알림 신호 (노트가 끝으로 떨어짐)
    output reg o_miss_t1, 
    output reg o_miss_t2,
    
    // 판정선(맨 왼쪽) 상태 알림 신호
    output o_hit_t1, // Track 1 판정존에 노트 있음!
    output o_hit_t2,  // Track 2 판정존에 노트 있음!
    
    // 현재 판정선에 있는 노트의 음계 값
    output reg [31:0] o_curr_pitch_t1, 
    output reg [31:0] o_curr_pitch_t2
);

    // ====================================================
    // [Part 1] 노트 스크롤링 로직 (Buffer & Scroll)
    // ====================================================
    
    // 1. 화면 버퍼 (16칸 x 2줄)
    reg [7:0] line1 [0:15]; // 윗줄
    reg [7:0] line2 [0:15]; // 아랫줄
    
    // 음계 버퍼 (화면과 똑같이 이동하는 투명한 데이터 버퍼)
    reg [31:0] pitch_buf_t1 [0:15];
    reg [31:0] pitch_buf_t2 [0:15];

    // 2. 노트 캡처 (Note Capture)
    // note_gen에서 보내는 신호는 아주 짧으므로(1클럭), 
    // 다음 스크롤이 일어날 때까지 기억해둬야 합니다.
    reg r_catch_t1, r_catch_t2;
    
    // 캡처용 레지스터
    reg [31:0] r_catch_pitch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_catch_t1 <= 0; r_catch_t2 <= 0;
            r_catch_pitch <= 0;
        end else begin
            if (i_note_t1) begin
                    r_catch_t1 <= 1;
                    r_catch_pitch <= i_gen_pitch; // 음계도 같이 캡처!
            end else if (scroll_en) r_catch_t1 <= 0; // 스크롤 후 초기화
            
            if (i_note_t2) begin
                r_catch_t2 <= 1;
                r_catch_pitch <= i_gen_pitch;
            end else if (scroll_en) r_catch_t2 <= 0;
        end
    end

    // 3. 스크롤 타이머 (Scroll Timer)
    // 300ms마다 한 칸씩 이동 (속도 조절 가능)
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

    // 4. 버퍼 업데이트 (Shift Logic)
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 초기화: 공백(" ")으로 채움 (ASCII 0x20)
            for (i=0; i<16; i=i+1) begin
                line1[i] <= 8'h20;
                line2[i] <= 8'h20;
                
                // 음계도 똑같이 초기화
                pitch_buf_t1[i] <= 0;
                pitch_buf_t2[i] <= 0;
            end
        end else if (scroll_en) begin
            // [왼쪽으로 이동]
            for (i=0; i<15; i=i+1) begin
                line1[i] <= line1[i+1];
                line2[i] <= line2[i+1];
                
                // 음계도 똑같이 이동
                pitch_buf_t1[i] <= pitch_buf_t1[i+1];
                pitch_buf_t2[i] <= pitch_buf_t2[i+1];
            end
            
            // [오른쪽 끝 채우기]
            // 잡았던 노트가 있으면 'O' (0x4F), 없으면 공백 ' ' (0x20)
            line1[15] <= (r_catch_t1) ? 8'h4F : 8'h20;
            line2[15] <= (r_catch_t2) ? 8'h4F : 8'h20;
            pitch_buf_t1[15] <= (r_catch_t1) ? r_catch_pitch : 0;
            pitch_buf_t2[15] <= (r_catch_t2) ? r_catch_pitch : 0;
        end
    end
    
    // [Part 3] 판정선 상태 출력 (맨 아래에 추가하세요!)
    // 맨 왼쪽(0번) 칸 버퍼 값이 'O'(0x4F)이면 1을 출력합니다.
    assign o_hit_t1 = (line1[0] == 8'h4F);
    assign o_hit_t2 = (line2[0] == 8'h4F);
    
    // 맨 왼쪽(0번) 칸의 정보를 내보냅니다.
    always @(*) begin
        o_curr_pitch_t1 = pitch_buf_t1[0];
        o_curr_pitch_t2 = pitch_buf_t2[0];
    end

    // ====================================================
    // [Part 2] LCD 드라이버 (Hardware Control FSM)
    // ====================================================
    
    // 상태 정의
    localparam S_INIT       = 0; // 초기화 대기
    localparam S_CMD_PRE    = 1; // 명령 전송 준비
    localparam S_CMD_SEND   = 2; // 명령 전송 (E=1)
    localparam S_CMD_HOLD   = 3; // 명령 완료 대기
    localparam S_DATA_PRE   = 4; // 데이터 전송 준비
    localparam S_DATA_SEND  = 5; // 데이터 전송 (E=1)
    localparam S_DATA_HOLD  = 6; // 데이터 완료 대기
    
    reg [3:0] state;
    reg [4:0] init_step;     // 초기화 단계
    reg [4:0] char_idx;      // 현재 쓰고 있는 글자 위치 (0~31)
    
    reg [31:0] delay_cnt;    // 타이밍 맞추기 위한 카운터
    
    // 50MHz 클럭 기준 딜레이 상수
    // 2ms = 100,000 클럭 (Clear 등 긴 명령)
    // 50us = 2,500 클럭 (일반 명령)
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
                // ------------------------------------------------
                // 1. 초기화 (Initialization Sequence)
                // ------------------------------------------------
                S_INIT: begin
                    delay_cnt <= delay_cnt + 1;
                    // 전원 켜고 충분히 기다림 (약 15ms 이상 -> 넉넉히 20ms)
                    if (delay_cnt > DLY_2MS * 10) begin 
                        delay_cnt <= 0;
                        state <= S_CMD_PRE;
                    end
                end

                // ------------------------------------------------
                // 2. 명령 보내기 (Command Send)
                // ------------------------------------------------
                S_CMD_PRE: begin
                    o_lcd_rs <= 0; // 명령 모드
                    o_lcd_rw <= 0; // 쓰기
                    o_lcd_e  <= 0;
                    
                    // 초기화 단계별 명령어 설정
                    case (init_step)
                        0: o_lcd_data <= 8'h38; // Function Set (8bit, 2line)
                        1: o_lcd_data <= 8'h0C; // Display ON, Cursor OFF
                        2: o_lcd_data <= 8'h06; // Entry Mode (Auto Inc)
                        3: o_lcd_data <= 8'h01; // Clear Display
                        4: o_lcd_data <= 8'h80; // Line 1 시작 주소 (0x80)
                        5: o_lcd_data <= 8'hC0; // Line 2 시작 주소 (0xC0)
                        default: o_lcd_data <= 8'h80; // (Refresh Loop 시작)
                    endcase
                    state <= S_CMD_SEND;
                end

                S_CMD_SEND: begin
                    o_lcd_e <= 1; // Enable Pulse High
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt > 50) begin // 적당한 펄스 폭 유지
                        delay_cnt <= 0;
                        state <= S_CMD_HOLD;
                    end
                end
                
                S_CMD_HOLD: begin
                    o_lcd_e <= 0; // Enable Pulse Low
                    delay_cnt <= delay_cnt + 1;
                    
                    // Clear 명령(step 3)은 오래 걸림 (2ms), 나머지는 빠름 (50us)
                    if ((init_step == 3 && delay_cnt > DLY_2MS) || 
                        (init_step != 3 && delay_cnt > DLY_50US)) begin
                        
                        delay_cnt <= 0;
                        
                        // 초기화 중이면 다음 단계로
                        if (init_step < 4) begin
                            init_step <= init_step + 1;
                            state <= S_CMD_PRE;
                        end 
                        // 초기화 끝났으면 데이터 쓰러 가기
                        else begin
                            // 화면 갱신 루프: Line 1 주소 세팅(4) -> Line 1 데이터 쓰기
                            // -> Line 2 주소 세팅(5) -> Line 2 데이터 쓰기
                            if (init_step == 4) begin
                                char_idx <= 0;      // 0~15번 글자 쓸 준비
                                state <= S_DATA_PRE; 
                            end else if (init_step == 5) begin
                                char_idx <= 16;     // 16~31번 글자 쓸 준비
                                state <= S_DATA_PRE;
                            end
                        end
                    end
                end

                // ------------------------------------------------
                // 3. 데이터 보내기 (Data Send - 화면 그리기)
                // ------------------------------------------------
                S_DATA_PRE: begin
                    o_lcd_rs <= 1; // 데이터 모드
                    o_lcd_rw <= 0;
                    o_lcd_e  <= 0;
                    
                    // 현재 char_idx에 맞는 버퍼 내용 가져오기
                    if (char_idx < 16) 
                        o_lcd_data <= line1[char_idx];      // 윗줄
                    else 
                        o_lcd_data <= line2[char_idx - 16]; // 아랫줄
                        
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
                    if (delay_cnt > DLY_50US) begin // 50us 대기
                        delay_cnt <= 0;
                        
                        // 다음 글자로 이동
                        if (char_idx == 15) begin
                            // 윗줄 다 썼으면 -> 아랫줄 주소 설정하러 가기
                            init_step <= 5; 
                            state <= S_CMD_PRE;
                        end else if (char_idx == 31) begin
                            // 아랫줄 다 썼으면 -> 다시 윗줄 주소 설정하러 가기 (무한 루프)
                            init_step <= 4; 
                            state <= S_CMD_PRE;
                        end else begin
                            // 같은 줄 다음 글자
                            char_idx <= char_idx + 1;
                            state <= S_DATA_PRE;
                        end
                    end
                end
            endcase
        end
    end

endmodule