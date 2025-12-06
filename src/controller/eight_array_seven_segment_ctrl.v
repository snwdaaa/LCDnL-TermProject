module eight_array_seven_segment_ctrl (
    input clk,
    input rst,
    input [1:0] i_judge,     // 판정 텍스트용 (왼쪽 4자리)
    input [15:0] i_data,     // 누적 점수용 (오른쪽 4자리)
    output reg [7:0] o_seg,  // Segment Pattern (Active High: 1=ON)
    output reg [7:0] o_com   // Common (Active Low: 0=Select)
);

    // =================================================================
    // [1] 패턴 정의 (Active High: 1일 때 켜짐)
    // 순서 가정: {dp, g, f, e, d, c, b, a}
    // =================================================================
    
    // 숫자 패턴 (0~9)
    localparam SEG_0 = 8'b0011_1111; // 0 (a,b,c,d,e,f ON)
    localparam SEG_1 = 8'b0000_0110; // 1 (b,c ON) -> 사용자 예시 일치!
    localparam SEG_2 = 8'b0101_1011; // 2 (a,b,d,e,g ON) -> 사용자 예시 일치!
    localparam SEG_3 = 8'b0100_1111; // 3
    localparam SEG_4 = 8'b0110_0110; // 4
    localparam SEG_5 = 8'b0110_1101; // 5
    localparam SEG_6 = 8'b0111_1101; // 6
    localparam SEG_7 = 8'b0010_0111; // 7 (또는 0000_0111)
    localparam SEG_8 = 8'b0111_1111; // 8
    localparam SEG_9 = 8'b0110_1111; // 9

    // 알파벳 패턴 (판정 텍스트용)
    localparam CH_P   = 8'b0111_0011; // P
    localparam CH_F   = 8'b0111_0001; // F
    localparam CH_C   = 8'b0011_1001; // C
    localparam CH_t   = 8'b0111_1000; // t
    localparam CH_n   = 8'b0101_0100; // n
    localparam CH_r   = 8'b0101_0000; // r
    localparam CH_m   = 8'b0011_0111; // m (n과 비슷하게 처리하거나 근사)
    localparam CH_L   = 8'b0011_1000; // L
    localparam CH_M   = 8'b0011_0111; // M (표현 한계로 n/m 등과 비슷하게 처리)
    localparam CH_I   = 8'b0000_0110; // I (1과 동일)
    localparam CH_S   = 8'b0110_1101; // S (5와 동일)
    localparam CH_BLK = 8'b0000_0000; // 꺼짐 (All 0)

    // =================================================================
    // [2] 스캐닝 로직
    // =================================================================
    reg [16:0] scan_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) scan_cnt <= 0;
        else scan_cnt <= scan_cnt + 1;
    end
    
    // 상위 3비트를 사용하여 0~7번 자리를 순환 (Scan Speed)
    wire [2:0] scan_idx = scan_cnt[16:14];

    // =================================================================
    // [3] 출력 로직
    // =================================================================
    reg [3:0] digit_val;

    always @(*) begin
        // 1. Common 핀 제어 (보통 Common은 Active Low 유지)
        // 만약 Common도 반대라면 `~`를 제거하세요. (현재: 0일 때 켜짐)
        o_com = ~(8'b0000_0001 << scan_idx); 

        // 2. 구역별 데이터 출력
        if (scan_idx >= 4) begin 
            // [왼쪽 4자리: 7,6,5,4] -> 판정 텍스트 Zone
            case (i_judge)
                2'b11: begin // Perfect -> "PFCt"
                    case(scan_idx) 
                        3'd7:o_seg=CH_P; 3'd6:o_seg=CH_F; 3'd5:o_seg=CH_C; 3'd4:o_seg=CH_t; 
                        default:o_seg=CH_BLK; 
                    endcase
                end
                2'b10: begin // Normal -> "nrmL"
                    case(scan_idx) 
                        3'd7:o_seg=CH_n; 3'd6:o_seg=CH_r; 3'd5:o_seg=CH_m; 3'd4:o_seg=CH_L; 
                        default:o_seg=CH_BLK; 
                    endcase
                end
                2'b01: begin // Miss -> "MISS"
                    case(scan_idx) 
                        3'd7:o_seg=CH_M; 3'd6:o_seg=CH_I; 3'd5:o_seg=CH_S; 3'd4:o_seg=CH_S; 
                        default:o_seg=CH_BLK; 
                    endcase
                end
                default: o_seg = CH_BLK;
            endcase
        end 
        else begin 
            // [오른쪽 4자리: 3,2,1,0] -> 점수 Zone
            case (scan_idx)
                3'd0: digit_val = i_data % 10;
                3'd1: digit_val = (i_data / 10) % 10;
                3'd2: digit_val = (i_data / 100) % 10;
                3'd3: digit_val = (i_data / 1000) % 10;
                default: digit_val = 4'hF;
            endcase

            case (digit_val)
                4'd0:o_seg=SEG_0; 4'd1:o_seg=SEG_1; 4'd2:o_seg=SEG_2; 4'd3:o_seg=SEG_3;
                4'd4:o_seg=SEG_4; 4'd5:o_seg=SEG_5; 4'd6:o_seg=SEG_6; 4'd7:o_seg=SEG_7;
                4'd8:o_seg=SEG_8; 4'd9:o_seg=SEG_9; default:o_seg=CH_BLK;
            endcase
        end
    end
endmodule