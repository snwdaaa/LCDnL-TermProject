`timescale 1ns / 1ps

module NOTE_GEN_TESTBENCH;

    // 1. 입력 신호 (우리가 조작할 것들)
    reg clk;
    reg rst;
    reg [31:0] cur_time; // 가짜 게임 타이머

    // 2. 출력 신호 (관찰할 것들)
    wire note_t1;    // 윗줄 노트 신호
    wire note_t2;    // 아랫줄 노트 신호
    wire game_end;   // 게임 종료 신호

    // 3. 검증할 모듈(DUT) 연결
    note_gen u_note_gen (
        .clk(clk),
        .rst(rst),
        .i_cur_time(cur_time), // 여기에 가짜 시간을 넣습니다
        .o_note_t1(note_t1),
        .o_note_t2(note_t2),
        .o_game_end(game_end)
    );

    // 4. 클럭 생성 (100MHz 가정, 주기 10ns)
    always #5 clk = ~clk;

    // 5. 테스트 시나리오
    initial begin
        // 초기화
        clk = 0;
        rst = 1;
        cur_time = 0;

        // 1. 리셋 해제
        #20 rst = 0;
        
        // 2. 시간 여행 시작! (빠르게 시간을 올려봅니다)
        $display("Start Simulation: Note Generation Test");

        // 0ms부터 8000ms까지 10ms 단위로 시간을 팍팍 증가시킴
        // (실제 게임보다 훨씬 빠르게 돌리는 겁니다)
        repeat (800) begin
            #10; // 10ns 대기 (1클럭)
            cur_time = cur_time + 10; // 시간을 10ms씩 건너뜀
        end
        
        // 3. 시뮬레이션 종료
        #100;
        $display("Simulation Finish!");
        $finish;
    end

    // 6. 모니터링 (로그 출력)
    // 노트 신호가 1이 될 때마다 텍스트로 알려줌
    always @(posedge clk) begin
        if (note_t1) 
            $display("[NOTE] Track 1 Fire! at Time: %d ms", cur_time);
        
        if (note_t2) 
            $display("[NOTE] Track 2 Fire! at Time: %d ms", cur_time);

        if (game_end)
            $display("[END] Game Over signal at Time: %d ms", cur_time);
    end

endmodule