module seven_segment_ctrl (
    input clk,              // 시스템 클럭
    input rst,              // 리셋
    input [1:0] i_judge,    // 판정 입력 (00:None, 01:Miss, 10:Normal, 11:Perfect)
    
    output reg [7:0] o_seg, // 7-Segment 데이터 핀 (a,b,c,d,e,f,g,dp)
    output reg [7:0] o_com  // 7-Segment 자릿수 선택 핀 (Common)
);

    // ====================================================
    // Part 1: 점수 계산 로직 (Score Logic)
    // ====================================================
    reg [13:0] score;       // 내부 점수 저장 레지스터 (0 ~ 9999)
    reg [1:0] prev_judge;   // Edge Detection용 이전 상태 저장

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            score <= 0;
            prev_judge <= 0;
        end else begin
            // [Edge Detection] 판정 신호가 변하는 순간(Rising Edge)만 포착
            if (i_judge != 0 && i_judge != prev_judge) begin
                case (i_judge)
                    2'b11: score <= score + 2; // Perfect: +2점
                    2'b10: score <= score + 1; // Normal: +1점
                    2'b01: score <= score;     // Miss: 0점 (그대로)
                    default: score <= score;
                endcase
            end
            prev_judge <= i_judge; // 현재 상태를 과거로 저장
        end
    end

    // ====================================================
    // Part 2: 10진수 분리 (Binary to BCD)
    // ====================================================
    // 4자리 숫자 분리 (예: 1234 -> 1, 2, 3, 4)
    wire [3:0] digit_1 = score % 10;
    wire [3:0] digit_10 = (score / 10) % 10;
    wire [3:0] digit_100 = (score / 100) % 10;
    wire [3:0] digit_1000 = (score / 1000) % 10;

    // ====================================================
    // Part 3: 스캐닝 및 디스플레이 제어 (Display Driver)
    // ====================================================
    reg [16:0] scan_cnt; // 스캔 속도 조절용 타이머
    
    always @(posedge clk or posedge rst) begin
        if (rst) scan_cnt <= 0;
        else scan_cnt <= scan_cnt + 1;
    end

    // 타이머의 상위 2비트를 사용하여 00->01->10->11 순서로 자릿수 순회
    wire [1:0] scan_idx = scan_cnt[16:15];
    reg [3:0] current_digit_value; // 현재 켜질 자리에 표시할 숫자

    // 1. 자릿수 선택 (Active Low 가정: 0일 때 켜짐)
    always @(*) begin
        // 일단 다 끄고 시작 (초기화)
        o_com = 8'b11111111; 
        
        case (scan_idx)
            2'b00: begin
                o_com = 8'b11111110;       // 첫 번째 자리 (일의 자리, 우측)
                current_digit_value = digit_1;
            end
            2'b01: begin
                o_com = 8'b11111101;       // 두 번째 자리 (십의 자리)
                current_digit_value = digit_10;
            end
            2'b10: begin
                o_com = 8'b11111011;       // 세 번째 자리 (백의 자리)
                current_digit_value = digit_100;
            end
            2'b11: begin
                o_com = 8'b11110111;       // 네 번째 자리 (천의 자리, 좌측)
                current_digit_value = digit_1000;
            end
        endcase
    end

    // 2. 숫자 패턴 디코딩 (Active Low 가정: 0일 때 켜짐)
    // a~g, dp 순서
    always @(*) begin
        case (current_digit_value)
            4'h0: o_seg = 8'b11000000; // 0
            4'h1: o_seg = 8'b11111001; // 1
            4'h2: o_seg = 8'b10100100; // 2
            4'h3: o_seg = 8'b10110000; // 3
            4'h4: o_seg = 8'b10011001; // 4
            4'h5: o_seg = 8'b10010010; // 5
            4'h6: o_seg = 8'b10000010; // 6
            4'h7: o_seg = 8'b11111000; // 7
            4'h8: o_seg = 8'b10000000; // 8
            4'h9: o_seg = 8'b10010000; // 9
            default: o_seg = 8'b11111111; // Off
        endcase
    end

endmodule