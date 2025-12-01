module u_game_led (
    input clk,              // 시스템 클럭 (100MHz or 50MHz)
    input rst,              // 리셋 신호
    input i_tick,           // 1ms 틱 (clk_div 모듈에서 받아옴)
    input i_spawn_note,     // 노트 생성 신호 (1 = 노트 생성, 악보 or 버튼에서 입력)
    output reg [7:0] o_led, // LED 출력 (이걸 보드 LED 핀에 연결)
    output o_is_target      // [중요] 타겟(LED8) 도착 알림 신호 (나중에 판정 모듈에 연결)
);

    // [1] 속도 조절 파라미터 (난이도 조절)
    // 200 = 200ms마다 한 칸 이동. 숫자를 줄이면 빨라집니다.
    parameter NOTE_SPEED = 200; 

    reg [31:0] speed_cnt;
    wire move_en; // 이동 허가 신호

    // [2] 이동 타이밍 생성 로직 (Timer)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            speed_cnt <= 0;
        end else if (i_tick) begin
            // NOTE_SPEED 만큼 1ms 틱을 셉니다.
            if (speed_cnt >= NOTE_SPEED - 1) begin
                speed_cnt <= 0;
            end else begin
                speed_cnt <= speed_cnt + 1;
            end
        end
    end

    // 카운터가 0이 되는 순간마다 1번씩만 High가 됩니다.
    assign move_en = (i_tick && (speed_cnt == 0));

    // [3] 시프트 레지스터 로직 (핵심: 데이터 이동)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_led <= 8'b00000000; // 초기화: 모든 불 끄기
        end else if (move_en) begin
            // [이동 원리: Left -> Right]
            // o_led 값을 왼쪽으로 Shift (<< 1) 하여 데이터를 상위 비트로 밉니다.
            // 빈 자리가 된 0번 비트(LSB) 자리에 i_spawn_note 값을 채워 넣습니다.
            // 예: 00000000 -> 00000001 -> 00000010 -> ... -> 10000000
            o_led <= (o_led << 1) | i_spawn_note;
        end
    end

    // [4] 타겟 도착 확인
    // 가장 오른쪽(LED8)인 7번 비트에 불이 들어왔는지 확인
    assign o_is_target = o_led[7]; 

endmodule