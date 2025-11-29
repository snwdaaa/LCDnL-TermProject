`timescale 1ns / 1ps

module CLK_TESTBENCH;

    // 1. 입력 신호 선언 (reg)
    reg clk;
    reg rst;

    // 2. 검증할 모듈(DUT) 인스턴스 생성
    sys_base u_sys_base (
        .clk(clk),
        .rst(rst)
    );

    // 3. 50MHz 클럭 생성 (주기 20ns)
    // 10ns마다 값을 뒤집으면 주기는 20ns가 됩니다.
    always #10 clk = ~clk;

    // 4. 테스트 시나리오
    initial begin
        // 초기화
        clk = 0;
        rst = 1; // 리셋 꾹 누르기

        // 시뮬레이션 시작 메시지
        $display("Simulation Start!");

        // 100ns 후 리셋 해제 (동작 시작)
        #100;
        rst = 0;
        $display("Reset released. Game Timer should start counting...");

        // 충분한 시간 동안 시뮬레이션 수행
        // 주의: CNT_MAX를 줄이지 않았다면 1ms를 보기 위해 매우 오래 돌려야 합니다.
        // 여기서는 예시로 5000ns만 돌립니다.
        #5000;

        $display("Simulation Finish!");
        $finish;
    end
    
    // 5. 모니터링 (옵션)
    // 시뮬레이션 로그창에 값을 텍스트로 찍어보고 싶다면 아래 구문 활용
    // u_sys_base 내부의 u_game_timer 모듈의 cur_time 값을 훔쳐봅니다.
    always @(posedge clk) begin
        // 값이 변할 때마다 로그 출력 (Hierarchical Reference 사용)
        if (u_sys_base.w_game_tick) begin
            $display("Time: %d ms", u_sys_base.w_cur_time);
        end
    end

endmodule