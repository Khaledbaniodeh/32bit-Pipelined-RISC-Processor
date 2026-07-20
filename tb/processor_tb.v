`timescale 1ns/1ps

module processor_tb;
    reg        clk;
    reg        rst;
    reg        imem_wr_en;
    reg  [7:0] imem_wr_addr;
    reg [31:0] imem_wr_data;

    wire [31:0] dbg_PC;
    wire [31:0] dbg_R0, dbg_R1, dbg_R2, dbg_R3, dbg_R4, dbg_R5, dbg_R6, dbg_R7, dbg_R14, dbg_MEM0;

    Processor DUT (
        .CLK         (clk),
        .RST         (rst),
        .IMem_WrEn   (imem_wr_en),
        .IMem_WrAddr (imem_wr_addr),
        .IMem_WrData (imem_wr_data),
        .dbg_PC      (dbg_PC),
        .dbg_R1      (dbg_R1),
        .dbg_R2      (dbg_R2),
        .dbg_R3      (dbg_R3),
        .dbg_R4      (dbg_R4),
        .dbg_R5      (dbg_R5),
        .dbg_R6      (dbg_R6),
        .dbg_R0      (dbg_R0),
        .dbg_R7      (dbg_R7),
        .dbg_R14     (dbg_R14),
        .dbg_MEM0    (dbg_MEM0)
    );

    // Clock period = 20 ns
    // Processor works on posedge CLK.
    always #10 clk = ~clk;

    // R-Type: opcode[31:26], Rd[25:22], Rs[21:18], Rt[17:14], unused[13:0]
    function [31:0] R;
        input [5:0] opcode;
        input [3:0] rd;
        input [3:0] rs;
        input [3:0] rt;
        begin
            R = {opcode, rd, rs, rt, 14'd0};
        end
    endfunction

    // I-Type: opcode[31:26], Rt[25:22], Rs[21:18], Imm[17:0]
    function [31:0] I;
        input [5:0] opcode;
        input [3:0] rt;
        input [3:0] rs;
        input signed [17:0] imm;
        begin
            I = {opcode, rt, rs, imm[17:0]};
        end
    endfunction

    // J-Type: opcode[31:26], Offset[25:0]
    function [31:0] J;
        input [5:0] opcode;
        input signed [25:0] offset;
        begin
            J = {opcode, offset[25:0]};
        end
    endfunction

    // Internal HALT used only by the testbench/program
    function [31:0] HALT;
        begin
            HALT = {6'd63, 26'd0};
        end
    endfunction

    task write_imem;
        input [7:0]  addr;
        input [31:0] data;
        begin
            imem_wr_addr = addr;
            imem_wr_data = data;
            imem_wr_en   = 1'b1;
            #2;
            imem_wr_en   = 1'b0;
            #2;
        end
    endtask

    task clear_imem;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1)
                write_imem(i[7:0], 32'h00000000); // ADD R0,R0,R0 = NOP
        end
    endtask

    task reset_processor;
        begin
            clk = 1'b0;
            rst = 1'b0;
            #25;
            rst = 1'b1;
        end
    endtask

    task dump;
        begin
            $display("KERNEL: T=%0d | PC=%0d | R0=%0d R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d R6=%0d R7=%0d R14=%0d MEM0=%0d",
                     $time, dbg_PC, dbg_R0, dbg_R1, dbg_R2, dbg_R3, dbg_R4, dbg_R5, dbg_R6, dbg_R7, dbg_R14, dbg_MEM0);
        end
    endtask

    task check;
        input [255:0] test_name;
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual === expected)
                $display("KERNEL: PASS: %0s = %0d", test_name, actual);
            else
                $display("KERNEL: FAIL: %0s expected=%0d actual=%0d hex_actual=%h",
                         test_name, expected, actual, actual);
        end
    endtask

    initial begin
        imem_wr_en   = 1'b0;
        imem_wr_addr = 8'd0;
        imem_wr_data = 32'd0;

        // =========================================================
        // Program 1: Arithmetic, logical, shift, memory, and SWAP
        // =========================================================
        $display("KERNEL: ===== Program 1: Required ISA Arithmetic/Logic/Memory/SWAP =====");
        clear_imem();

        write_imem(0,  I(6'd10, 4'd1, 4'd0, 18'd5));   // ADDI R1,R0,5
        write_imem(1,  I(6'd10, 4'd2, 4'd0, 18'd10));  // ADDI R2,R0,10
        write_imem(2,  R(6'd0,  4'd3, 4'd1, 4'd2));    // ADD R3,R1,R2 = 15
        write_imem(3,  R(6'd1,  4'd4, 4'd2, 4'd1));    // SUB R4,R2,R1 = 5
        write_imem(4,  R(6'd2,  4'd5, 4'd1, 4'd2));    // AND R5,R1,R2 = 0
        write_imem(5,  R(6'd3,  4'd6, 4'd1, 4'd2));    // OR R6,R1,R2 = 15
        write_imem(6,  R(6'd4,  4'd7, 4'd1, 4'd2));    // XOR R7,R1,R2 = 15
        write_imem(7,  R(6'd6,  4'd6, 4'd1, 4'd1));    // SLL R6,R1,R1 = 160
        write_imem(8,  R(6'd7,  4'd6, 4'd6, 4'd1));    // SRL R6,R6,R1 = 5
        write_imem(9,  R(6'd8,  4'd5, 4'd0, 4'd0));    // CLR R5 = 0
        write_imem(10, I(6'd14, 4'd1, 4'd0, 18'd0));   // SW R1,0(R0), MEM[0]=5
        write_imem(11, I(6'd13, 4'd5, 4'd0, 18'd0));   // LW R5,0(R0), R5=5
        write_imem(12, R(6'd0,  4'd6, 4'd5, 4'd1));    // ADD R6,R5,R1 = 10
        write_imem(13, I(6'd15, 4'd2, 4'd0, 18'd0));   // SWAP R2,0(R0): R2=5, MEM[0]=10
        write_imem(14, I(6'd13, 4'd5, 4'd0, 18'd0));   // LW R5,0(R0), R5=10
        write_imem(15, HALT());

        reset_processor();

        repeat (40) begin
            #20 dump();
        end

        check("R0 hardwired zero", dbg_R0, 32'd0);
        check("R1 ADDI", dbg_R1, 32'd5);
        check("R2 after SWAP", dbg_R2, 32'd5);
        check("R3 ADD", dbg_R3, 32'd15);
        check("R4 SUB", dbg_R4, 32'd5);
        check("R5 LW after SWAP", dbg_R5, 32'd10);
        check("R6 load-use ADD", dbg_R6, 32'd10);
        check("R7 XOR", dbg_R7, 32'd15);
        check("MEM0 after SWAP", dbg_MEM0, 32'd10);

        // =========================================================
        // Program 2: BEQ, BNE, J, JAL, JR
        // =========================================================
        $display("KERNEL: ===== Program 2: Branch + Jump + JAL + JR =====");
        clear_imem();

        write_imem(0,  I(6'd10, 4'd1, 4'd0, 18'd5));   // R1=5
        write_imem(1,  I(6'd10, 4'd2, 4'd0, 18'd5));   // R2=5
        write_imem(2,  I(6'd16, 4'd1, 4'd2, 18'd5));   // BEQ R1,R2,+5 -> PC=7
        write_imem(3,  I(6'd10, 4'd3, 4'd0, 18'd99));  // skipped
        write_imem(4,  I(6'd10, 4'd4, 4'd0, 18'd99));  // skipped
        write_imem(5,  I(6'd10, 4'd5, 4'd0, 18'd99));  // skipped
        write_imem(6,  I(6'd10, 4'd6, 4'd0, 18'd99));  // skipped
        write_imem(7,  I(6'd10, 4'd3, 4'd0, 18'd7));   // R3=7
        write_imem(8,  I(6'd17, 4'd1, 4'd2, 18'd3));   // BNE false, PC=9
        write_imem(9,  I(6'd10, 4'd4, 4'd0, 18'd4));   // R4=4
        write_imem(10, J(6'd18, 26'd3));                // J +3 -> PC=13
        write_imem(11, I(6'd10, 4'd5, 4'd0, 18'd55));  // skipped
        write_imem(12, I(6'd10, 4'd5, 4'd0, 18'd66));  // skipped
        write_imem(13, J(6'd19, 26'd3));                // JAL +3 -> PC=16, R14=14
        write_imem(14, J(6'd18, 26'd5));                // target after JR: J +5 -> PC=19
        write_imem(15, I(6'd10, 4'd6, 4'd0, 18'd88));  // skipped
        write_imem(16, I(6'd10, 4'd6, 4'd0, 18'd77));  // R6=77
        write_imem(17, R(6'd9,  4'd0, 4'd14, 4'd0));   // JR R14 -> PC=14
        write_imem(18, I(6'd10, 4'd6, 4'd0, 18'd99));  // skipped
        write_imem(19, I(6'd10, 4'd5, 4'd0, 18'd20));  // R5=20
        write_imem(20, HALT());

        reset_processor();

        repeat (55) begin
            #20 dump();
        end

        check("R1", dbg_R1, 32'd5);
        check("R2", dbg_R2, 32'd5);
        check("R3 after BEQ target", dbg_R3, 32'd7);
        check("R4 after BNE false", dbg_R4, 32'd4);
        check("R5 after J/JR path", dbg_R5, 32'd20);
        check("R6 after JAL target", dbg_R6, 32'd77);
        check("R14 link register", dbg_R14, 32'd14);

        // =========================================================
        // Program 3: Forwarding and load-use hazard
        // =========================================================
        $display("KERNEL: ===== Program 3: Forwarding + Load-Use Hazard =====");
        clear_imem();

        write_imem(0, I(6'd10, 4'd1, 4'd0, 18'd4));   // R1=4
        write_imem(1, R(6'd0,  4'd2, 4'd1, 4'd1));    // R2=R1+R1=8
        write_imem(2, R(6'd0,  4'd3, 4'd2, 4'd1));    // R3=R2+R1=12
        write_imem(3, I(6'd14, 4'd3, 4'd0, 18'd0));   // MEM[0]=12
        write_imem(4, I(6'd13, 4'd4, 4'd0, 18'd0));   // R4=MEM[0]=12
        write_imem(5, R(6'd0,  4'd5, 4'd4, 4'd1));    // R5=R4+R1=16
        write_imem(6, HALT());

        reset_processor();

        repeat (35) begin
            #20 dump();
        end

        check("R1", dbg_R1, 32'd4);
        check("R2 forwarding", dbg_R2, 32'd8);
        check("R3 forwarding", dbg_R3, 32'd12);
        check("R4 load", dbg_R4, 32'd12);
        check("R5 load-use hazard result", dbg_R5, 32'd16);
        check("MEM0 store", dbg_MEM0, 32'd12);

        $display("KERNEL: ===== Simulation Complete =====");

        // The test sequence finishes around 3619 ns.
        // This delay extends the waveform to about 24 us total.
        // 24000 ns - 3619 ns = 20381 ns.
        #20381;

        $finish;
    end

endmodule
