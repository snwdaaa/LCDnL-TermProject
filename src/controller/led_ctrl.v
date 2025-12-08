module led_ctrl (
    input clk,              // 시스템 클럭 (50MHz)
    input rst,              // 리셋
    input i_tick,           // 1ms 틱 (속도 조절용)
    input i_game_start,     // 게임 시작 신호 (1일 때만 움직임)
    input i_game_over,      // (선택) 게임 오버 시 깜빡이게 할 수도 있음
    
    output reg [7:0] o_led  // 8개 LED 출력
);

    // ==========================================
    // 설정: 속도 조절
    // ==========================================
    parameter MOVE_SPEED = 100; // 100ms마다 한 칸 이동 (작을수록 빠름)
    
    reg [31:0] move_cnt;    // 시간 카운터
    reg [2:0]  led_idx;     // 현재 켜진 LED 위치 (0~7)
    reg        dir;         // 이동 방향 (0: 왼쪽->오른쪽, 1: 오른쪽->왼쪽)

    // ==========================================
    // 동작 로직
    // ==========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_led <= 8'b0000_0000;
            move_cnt <= 0;
            led_idx <= 0;
            dir <= 0;
        end 
        else if (i_game_start && !i_game_over) begin
            // 1. 타이머 동작 (MOVE_SPEED 마다 트리거)
            if (i_tick) begin
                if (move_cnt >= MOVE_SPEED - 1) begin
                    move_cnt <= 0;
                    
                    // 2. LED 위치 이동 및 방향 전환
                    if (dir == 0) begin 
                        // [정방향] 0 -> 7
                        if (led_idx == 7) begin
                            dir <= 1;       // 끝에 닿으면 방향 반대로
                            led_idx <= 6;
                        end else begin
                            led_idx <= led_idx + 1;
                        end
                    end 
                    else begin 
                        // [역방향] 7 -> 0
                        if (led_idx == 0) begin
                            dir <= 0;       // 끝에 닿으면 방향 반대로
                            led_idx <= 1;
                        end else begin
                            led_idx <= led_idx - 1;
                        end
                    end
                end 
                else begin
                    move_cnt <= move_cnt + 1;
                end
            end
            
            // 3. 현재 위치의 LED 켜기 (Decoder)
            o_led <= (8'b1 << led_idx);
            
        end 
        else begin
            // 게임 중이 아닐 때는 모두 끄거나, 특정 패턴 유지
            o_led <= 8'b0000_0000;
            move_cnt <= 0;
            led_idx <= 0;
        end
    end

endmodule