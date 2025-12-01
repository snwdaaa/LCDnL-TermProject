module eight_array_seven_segment_ctrl (
    input clk,
    input rst,
    input [1:0] i_judge,    // 00:IDLE, 01:MISS, 10:NORMAL, 11:PERFECT
    output reg [7:0] o_seg, // Segment Pattern (a~g, dp)
    output reg [7:0] o_com  // Digit Selection (Active Low)
);

    // [1] 문자 패턴 정의 (Active Low: 0일 때 켜짐)
    // a=MSB(7), dp=LSB(0) 또는 a=0, dp=7 등 보드마다 다름. 
    // 여기서는 일반적인 [7:0] = {dp, g, f, e, d, c, b, a} 순서 혹은 보드 메뉴얼 참조.
    // ※ HBE-Combo II 보드 특성에 맞춰 a(bit0)~g(bit6), dp(bit7)로 가정하고, 0=ON으로 설정합니다.
    // 비트 순서가 다르면 .xdc 파일에서 매핑을 바꾸거나 여기서 값을 뒤집으면 됩니다.
    
    localparam CH_BLK = 8'b1111_1111; // 꺼짐 (Blank)
    localparam CH_P   = 8'b0000_1100; // P
    localparam CH_E   = 8'b0000_0110; // E
    localparam CH_R   = 8'b1010_1111; // r (소문자 모양)
    localparam CH_F   = 8'b0000_1110; // F
    localparam CH_C   = 8'b0100_0110; // C
    localparam CH_T   = 8'b0000_0111; // t
    localparam CH_N   = 8'b1010_1011; // n
    localparam CH_O   = 8'b1010_0011; // o
    localparam CH_M   = 8'b1010_1010; // n 두개 겹친 모양 (M은 표현이 어려워 근사치 사용)
    localparam CH_I   = 8'b1111_1001; // I (1과 동일)
    localparam CH_S   = 8'b0001_0010; // S (5와 동일)
    localparam CH_A   = 8'b0000_1000; // A
    localparam CH_L   = 8'b1000_0111; // L

    // [2] 스캐닝 타이머 (Scanning Timer)
    // 8개 자리를 빠르게 순환하기 위한 카운터
    reg [16:0] scan_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) scan_cnt <= 0;
        else scan_cnt <= scan_cnt + 1;
    end
    
    // 상위 3비트를 사용하여 0~7번 자리를 순환 (2^3 = 8개)
    wire [2:0] scan_idx = scan_cnt[16:14];

    // [3] 자릿수 선택 및 문자 출력 로직
    // scan_idx(현재 켜진 자리)와 i_judge(현재 판정)에 따라 출력할 문자 결정
    // 자리 배치: scan_idx 7(왼쪽/MSB) -> 0(오른쪽/LSB)
    always @(*) begin
        // 1. Common 핀 제어 (Active Low) - 현재 scan_idx에 해당하는 자리만 0으로
        o_com = ~(8'b0000_0001 << scan_idx); 

        // 2. Segment 데이터 선택
        case (i_judge)
            // -----------------------------------------------------
            // Case 1: PERFECT ( "P E r F E C t _" )
            // -----------------------------------------------------
            2'b11: begin 
                case (scan_idx)
                    3'd7: o_seg = CH_P;   // [7] P
                    3'd6: o_seg = CH_E;   // [6] E
                    3'd5: o_seg = CH_R;   // [5] r
                    3'd4: o_seg = CH_F;   // [4] F
                    3'd3: o_seg = CH_E;   // [3] E
                    3'd2: o_seg = CH_C;   // [2] C
                    3'd1: o_seg = CH_T;   // [1] t
                    default: o_seg = CH_BLK; // 나머지 공백
                endcase
            end

            // -----------------------------------------------------
            // Case 2: NORMAL ( "n o r n A L _ _" )
            // -----------------------------------------------------
            2'b10: begin
                case (scan_idx)
                    3'd7: o_seg = CH_N;   // [7] n
                    3'd6: o_seg = CH_O;   // [6] o
                    3'd5: o_seg = CH_R;   // [5] r
                    3'd4: o_seg = CH_N;   // [4] n
                    3'd3: o_seg = CH_A;   // [3] A
                    3'd2: o_seg = CH_L;   // [2] L
                    default: o_seg = CH_BLK; // 나머지 공백
                endcase
            end

            // -----------------------------------------------------
            // Case 3: MISS ( "_ _ n I S S _ _" ) - 중앙 정렬 느낌
            // -----------------------------------------------------
            2'b01: begin
                case (scan_idx)
                    3'd5: o_seg = CH_N;   // [5] M (n 모양 대용)
                    3'd4: o_seg = CH_I;   // [4] I
                    3'd3: o_seg = CH_S;   // [3] S
                    3'd2: o_seg = CH_S;   // [2] S
                    default: o_seg = CH_BLK; // 나머지 공백
                endcase
            end

            // -----------------------------------------------------
            // Case 0: IDLE ( "_ _ _ _ _ _ _ _" )
            // -----------------------------------------------------
            default: o_seg = CH_BLK; // 아무것도 표시 안 함
        endcase
    end

endmodule