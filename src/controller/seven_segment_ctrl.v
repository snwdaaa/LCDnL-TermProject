module seven_segment_ctrl (
    input [1:0] i_judge,    // 00:IDLE, 01:MISS, 10:NORMAL, 11:PERFECT
    output reg [7:0] o_seg  // Single 7-Segment Pattern (Active Low)
);
    // 패턴 정의 (0=ON, dp,g,f,e,d,c,b,a 순서 가정)
    localparam SEG_0   = 8'b0111_1111; // 0 (Miss)
    localparam SEG_1   = 8'b0000_0110; // 1 (Normal)
    localparam SEG_2   = 8'b0101_1011; // 2 (Perfect)
    localparam SEG_BLK = 8'b0000_0000; // 꺼짐 (Idle)

    always @(*) begin
        case (i_judge)
            2'b11: o_seg = SEG_2;   // Perfect -> 2점
            2'b10: o_seg = SEG_1;   // Normal -> 1점
            2'b01: o_seg = SEG_0;   // Miss -> 0점
            default: o_seg = SEG_BLK; // IDLE 상태에선 끄기 (또는 0 유지 선택 가능)
        endcase
    end
endmodule