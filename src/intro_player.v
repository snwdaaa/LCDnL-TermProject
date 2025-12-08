module intro_player (
    input clk,
    input rst,
    input i_tick,          // 1ms 틱 (sys_base에서 들어오는 타이밍 신호)
    input i_enable,        // 1일 때만 사이렌 울림 (게임 시작 전 or 종료 후)
    
    output reg o_play_en,      // 피에조 켜기/끄기
    output reg [31:0] o_pitch  // 피에조 주파수 값 (Counter Limit)
);

    // ==========================================
    // 데프콘 사이렌 주파수 설정
    // 공식: 50MHz / (Freq * 2)
    // ==========================================
    // 400Hz (저음) ~ 1000Hz (고음) 사이를 왕복
    localparam LOW_LIMIT  = 62500; // 400Hz
    localparam HIGH_LIMIT = 25000; // 1000Hz
    
    // 소리 변화 속도 (값이 클수록 빠르게 변함)
    // 1ms마다 이 값만큼 카운터 리밋을 줄이거나 늘림
    localparam STEP = 25; 

    reg direction; // 0: 음이 높아짐 (Limit 감소), 1: 음이 낮아짐 (Limit 증가)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_pitch   <= LOW_LIMIT;
            direction <= 0;
            o_play_en <= 0;
        end 
        else if (i_enable) begin
            o_play_en <= 1; // 소리 켜기

            // 1ms마다 주파수 변경 (부드러운 Sweep 효과)
            if (i_tick) begin
                if (direction == 0) begin 
                    // [상승 구간] 위~~~~ (Limit 값을 줄여서 고음으로)
                    if (o_pitch > HIGH_LIMIT) 
                        o_pitch <= o_pitch - STEP;
                    else 
                        direction <= 1; // 방향 전환 (이제 내려가자)
                end 
                else begin 
                    // [하강 구간] 웅~~~~ (Limit 값을 늘려서 저음으로)
                    if (o_pitch < LOW_LIMIT) 
                        o_pitch <= o_pitch + STEP;
                    else 
                        direction <= 0; // 방향 전환 (이제 올라가자)
                end
            end
        end 
        else begin
            // 비활성화 시 (게임 중일 때) 소리 끄고 초기화
            o_play_en <= 0;
            o_pitch   <= LOW_LIMIT; 
            direction <= 0;
        end
    end

endmodule