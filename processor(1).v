`timescale 1ns/1ps

// ============================================================
// ENCS4370 Project 2 - 32-bit RISC Processor
// Corrected to match the required project ISA exactly:
// R-Type: opcode[31:26], Rd[25:22], Rs[21:18], Rt[17:14], unused[13:0]
// I-Type: opcode[31:26], Rt[25:22], Rs[21:18], Imm[17:0]
// J-Type: opcode[31:26], Offset[25:0]
// Opcodes: ADD=0 ... JAL=19
// ============================================================

module ProgramCounter (
    input              CLK, RST, PCWrite,
    input      [31:0] PC_Next,
    output reg [31:0] PC_Out
);
    always @(posedge CLK or negedge RST) begin
        if (~RST)         PC_Out <= 32'd0;
        else if (PCWrite) PC_Out <= PC_Next;
    end
endmodule

module PCControl (
    input      [31:0] PC_Current, BranchTarget, JumpTarget, JRTarget,
    input             BranchTaken, Jump, JR,
    output     [31:0] PC_Next
);
    assign PC_Next = JR          ? JRTarget     :
                     Jump        ? JumpTarget   :
                     BranchTaken ? BranchTarget :
                                   PC_Current + 32'd1;
endmodule

module InstructionMemory (
    input      [31:0] Address,
    output     [31:0] Instruction,
    input             WrEn,
    input      [7:0]  WrAddr,
    input      [31:0] WrData
);
    reg [31:0] IMem [0:255];
    integer k;
    initial begin
        for (k = 0; k < 256; k = k + 1) IMem[k] = 32'h00000000;
    end

    always @(posedge WrEn) begin
        IMem[WrAddr] <= WrData;
    end

    assign Instruction = IMem[Address[7:0]];
endmodule

module IF_ID_Register (
    input              CLK, RST, IF_ID_Write, IF_ID_Flush,
    input      [31:0] IF_PC, IF_Instr,
    output reg [31:0] ID_PC, ID_Instr
);
    always @(posedge CLK or negedge RST) begin
        if (~RST || IF_ID_Flush) begin
            ID_PC    <= 32'd0;
            ID_Instr <= 32'd0;
        end else if (IF_ID_Write) begin
            ID_PC    <= IF_PC;
            ID_Instr <= IF_Instr;
        end
    end
endmodule

module RegisterFile (
    input              CLK, RST, RegWrite,
    input      [3:0]  ReadReg1, ReadReg2, WriteReg,
    input      [31:0] WriteData,
    output     [31:0] ReadData1, ReadData2,
    output     [31:0] R0out, R1out, R2out, R3out, R4out, R5out, R6out, R7out, R14out
);
    reg [31:0] Registers [0:15];
    integer i;

    always @(posedge CLK or negedge RST) begin
        if (~RST) begin
            for (i = 0; i < 16; i = i + 1) Registers[i] <= 32'd0;
        end else begin
            Registers[0] <= 32'd0;
            if (RegWrite && WriteReg != 4'd0) begin
                Registers[WriteReg] <= WriteData;
            end
        end
    end

    // Read bypass from WB stage. R0 is always hardwired to zero.
    assign ReadData1 = (ReadReg1 == 4'd0) ? 32'd0 :
                       (RegWrite && WriteReg == ReadReg1) ? WriteData : Registers[ReadReg1];
    assign ReadData2 = (ReadReg2 == 4'd0) ? 32'd0 :
                       (RegWrite && WriteReg == ReadReg2) ? WriteData : Registers[ReadReg2];

    assign R0out  = 32'd0;
    assign R1out  = Registers[1];
    assign R2out  = Registers[2];
    assign R3out  = Registers[3];
    assign R4out  = Registers[4];
    assign R5out  = Registers[5];
    assign R6out  = Registers[6];
    assign R7out  = Registers[7];
    assign R14out = Registers[14];
endmodule

module ControlUnit (
    input      [5:0] Opcode,
    output reg       ALUSrc, MemRead, MemWrite, MemToReg, RegWrite,
    output reg       Branch, Jump, Link, JR, SignOrZero, Halt
);
    always @(*) begin
        ALUSrc    = 1'b0;
        MemRead   = 1'b0;
        MemWrite  = 1'b0;
        MemToReg  = 1'b0;
        RegWrite  = 1'b0;
        Branch    = 1'b0;
        Jump      = 1'b0;
        Link      = 1'b0;
        JR        = 1'b0;
        SignOrZero= 1'b1;   // 1 = sign extend, 0 = zero extend
        Halt      = 1'b0;

        case (Opcode)
            6'd0, 6'd1, 6'd2, 6'd3, 6'd4,
            6'd5, 6'd6, 6'd7, 6'd8: begin
                RegWrite = 1'b1;              // ADD..CLR
            end

            6'd9: begin
                JR = 1'b1;                    // JR Rs
            end

            6'd10: begin
                RegWrite = 1'b1; ALUSrc = 1'b1; SignOrZero = 1'b1; // ADDI
            end

            6'd11: begin
                RegWrite = 1'b1; ALUSrc = 1'b1; SignOrZero = 1'b0; // ANDI
            end

            6'd12: begin
                RegWrite = 1'b1; ALUSrc = 1'b1; SignOrZero = 1'b0; // ORI
            end

            6'd13: begin
                RegWrite = 1'b1; ALUSrc = 1'b1; MemRead = 1'b1; MemToReg = 1'b1; // LW
            end

            6'd14: begin
                ALUSrc = 1'b1; MemWrite = 1'b1; // SW
            end

            6'd15: begin
                RegWrite = 1'b1; ALUSrc = 1'b1; MemRead = 1'b1; MemWrite = 1'b1; MemToReg = 1'b1; // SWAP
            end

            6'd16, 6'd17: begin
                Branch = 1'b1;                 // BEQ/BNE
            end

            6'd18: begin
                Jump = 1'b1;                   // J
            end

            6'd19: begin
                Jump = 1'b1; Link = 1'b1; RegWrite = 1'b1; // JAL
            end

            6'd63: begin
                Halt = 1'b1;                   // Simulation-only HALT, not part of required ISA
            end

            default: begin
                // NOP / undefined opcode
            end
        endcase
    end
endmodule

module SignZeroExtend18 (
    input      [17:0] Imm18,
    input             SignOrZero,
    output     [31:0] ExtImm
);
    assign ExtImm = SignOrZero ? {{14{Imm18[17]}}, Imm18} : {14'd0, Imm18};
endmodule

module ID_EX_Register (
    input              CLK, RST, ID_EX_Flush,
    input      [31:0] ID_PC, ID_ReadData1, ID_ReadData2, ID_ExtImm,
    input      [3:0]  ID_Rs, ID_RtSrc, ID_DestReg,
    input      [25:0] ID_Offset26,
    input             ID_ALUSrc, ID_MemRead, ID_MemWrite, ID_MemToReg, ID_RegWrite,
    input             ID_Branch, ID_Jump, ID_Link, ID_JR,
    input      [5:0]  ID_Opcode,
    output reg [31:0] EX_PC, EX_ReadData1, EX_ReadData2, EX_ExtImm,
    output reg [3:0]  EX_Rs, EX_RtSrc, EX_DestReg,
    output reg [25:0] EX_Offset26,
    output reg        EX_ALUSrc, EX_MemRead, EX_MemWrite, EX_MemToReg, EX_RegWrite,
    output reg        EX_Branch, EX_Jump, EX_Link, EX_JR,
    output reg [5:0]  EX_Opcode
);
    always @(posedge CLK or negedge RST) begin
        if (~RST || ID_EX_Flush) begin
            EX_PC        <= 32'd0;
            EX_ReadData1 <= 32'd0;
            EX_ReadData2 <= 32'd0;
            EX_ExtImm    <= 32'd0;
            EX_Rs        <= 4'd0;
            EX_RtSrc     <= 4'd0;
            EX_DestReg   <= 4'd0;
            EX_Offset26  <= 26'd0;
            EX_ALUSrc    <= 1'b0;
            EX_MemRead   <= 1'b0;
            EX_MemWrite  <= 1'b0;
            EX_MemToReg  <= 1'b0;
            EX_RegWrite  <= 1'b0;
            EX_Branch    <= 1'b0;
            EX_Jump      <= 1'b0;
            EX_Link      <= 1'b0;
            EX_JR        <= 1'b0;
            EX_Opcode    <= 6'd0;
        end else begin
            EX_PC        <= ID_PC;
            EX_ReadData1 <= ID_ReadData1;
            EX_ReadData2 <= ID_ReadData2;
            EX_ExtImm    <= ID_ExtImm;
            EX_Rs        <= ID_Rs;
            EX_RtSrc     <= ID_RtSrc;
            EX_DestReg   <= ID_DestReg;
            EX_Offset26  <= ID_Offset26;
            EX_ALUSrc    <= ID_ALUSrc;
            EX_MemRead   <= ID_MemRead;
            EX_MemWrite  <= ID_MemWrite;
            EX_MemToReg  <= ID_MemToReg;
            EX_RegWrite  <= ID_RegWrite;
            EX_Branch    <= ID_Branch;
            EX_Jump      <= ID_Jump;
            EX_Link      <= ID_Link;
            EX_JR        <= ID_JR;
            EX_Opcode    <= ID_Opcode;
        end
    end
endmodule

module ALUControl (
    input      [5:0] Opcode,
    output reg [3:0] ALUCtrl
);
    always @(*) begin
        case (Opcode)
            6'd0, 6'd10, 6'd13, 6'd14, 6'd15: ALUCtrl = 4'd0;  // ADD/address
            6'd1, 6'd16, 6'd17:               ALUCtrl = 4'd1;  // SUB/compare
            6'd2, 6'd11:                       ALUCtrl = 4'd2;  // AND
            6'd3, 6'd12:                       ALUCtrl = 4'd3;  // OR
            6'd4:                              ALUCtrl = 4'd4;  // XOR
            6'd5:                              ALUCtrl = 4'd5;  // NOR
            6'd6:                              ALUCtrl = 4'd6;  // SLL
            6'd7:                              ALUCtrl = 4'd7;  // SRL
            6'd8:                              ALUCtrl = 4'd8;  // CLR
            default:                           ALUCtrl = 4'd0;
        endcase
    end
endmodule

module ALU (
    input      [31:0] OperandA, OperandB,
    input      [3:0]  ALUCtrl,
    output reg [31:0] ALUResult,
    output            Zero
);
    assign Zero = (ALUResult == 32'd0);

    always @(*) begin
        case (ALUCtrl)
            4'd0: ALUResult = OperandA + OperandB;              // ADD
            4'd1: ALUResult = OperandA - OperandB;              // SUB
            4'd2: ALUResult = OperandA & OperandB;              // AND
            4'd3: ALUResult = OperandA | OperandB;              // OR
            4'd4: ALUResult = OperandA ^ OperandB;              // XOR
            4'd5: ALUResult = ~(OperandA | OperandB);           // NOR
            4'd6: ALUResult = OperandA << OperandB[4:0];        // SLL
            4'd7: ALUResult = OperandA >> OperandB[4:0];        // SRL
            4'd8: ALUResult = 32'd0;                            // CLR
            default: ALUResult = 32'd0;
        endcase
    end
endmodule

module EX_MEM_Register (
    input              CLK, RST, EX_MEM_Flush,
    input      [31:0] EX_BranchTarget, EX_LinkAddr, EX_ALUResult, EX_WriteData,
    input      [3:0]  EX_WriteReg,
    input             EX_Zero,
    input             EX_MemRead, EX_MemWrite, EX_MemToReg, EX_RegWrite, EX_Branch, EX_Link,
    input      [5:0]  EX_Opcode,
    output reg [31:0] MEM_BranchTarget, MEM_LinkAddr, MEM_ALUResult, MEM_WriteData,
    output reg [3:0]  MEM_WriteReg,
    output reg        MEM_Zero,
    output reg        MEM_MemRead, MEM_MemWrite, MEM_MemToReg, MEM_RegWrite, MEM_Branch, MEM_Link,
    output reg [5:0]  MEM_Opcode
);
    always @(posedge CLK or negedge RST) begin
        if (~RST || EX_MEM_Flush) begin
            MEM_BranchTarget <= 32'd0;
            MEM_LinkAddr     <= 32'd0;
            MEM_ALUResult    <= 32'd0;
            MEM_WriteData    <= 32'd0;
            MEM_WriteReg     <= 4'd0;
            MEM_Zero         <= 1'b0;
            MEM_MemRead      <= 1'b0;
            MEM_MemWrite     <= 1'b0;
            MEM_MemToReg     <= 1'b0;
            MEM_RegWrite     <= 1'b0;
            MEM_Branch       <= 1'b0;
            MEM_Link         <= 1'b0;
            MEM_Opcode       <= 6'd0;
        end else begin
            MEM_BranchTarget <= EX_BranchTarget;
            MEM_LinkAddr     <= EX_LinkAddr;
            MEM_ALUResult    <= EX_ALUResult;
            MEM_WriteData    <= EX_WriteData;
            MEM_WriteReg     <= EX_WriteReg;
            MEM_Zero         <= EX_Zero;
            MEM_MemRead      <= EX_MemRead;
            MEM_MemWrite     <= EX_MemWrite;
            MEM_MemToReg     <= EX_MemToReg;
            MEM_RegWrite     <= EX_RegWrite;
            MEM_Branch       <= EX_Branch;
            MEM_Link         <= EX_Link;
            MEM_Opcode       <= EX_Opcode;
        end
    end
endmodule

module DataMemory (
    input              CLK, RST, MemRead, MemWrite,
    input      [31:0] Address, WriteData,
    output     [31:0] ReadData,
    output     [31:0] Mem0out
);
    reg [31:0] DMem [0:255];
    integer j;

    always @(posedge CLK or negedge RST) begin
        if (~RST) begin
            for (j = 0; j < 256; j = j + 1) DMem[j] <= 32'd0;
        end else if (MemWrite) begin
            DMem[Address[7:0]] <= WriteData;
        end
    end

    assign ReadData = MemRead ? DMem[Address[7:0]] : 32'd0;
    assign Mem0out  = DMem[0];
endmodule

module MEM_WB_Register (
    input              CLK, RST,
    input      [31:0] MEM_LinkAddr, MEM_ReadData, MEM_ALUResult,
    input      [3:0]  MEM_WriteReg,
    input             MEM_MemToReg, MEM_RegWrite, MEM_Link,
    output reg [31:0] WB_LinkAddr, WB_ReadData, WB_ALUResult,
    output reg [3:0]  WB_WriteReg,
    output reg        WB_MemToReg, WB_RegWrite, WB_Link
);
    always @(posedge CLK or negedge RST) begin
        if (~RST) begin
            WB_LinkAddr  <= 32'd0;
            WB_ReadData  <= 32'd0;
            WB_ALUResult <= 32'd0;
            WB_WriteReg  <= 4'd0;
            WB_MemToReg  <= 1'b0;
            WB_RegWrite  <= 1'b0;
            WB_Link      <= 1'b0;
        end else begin
            WB_LinkAddr  <= MEM_LinkAddr;
            WB_ReadData  <= MEM_ReadData;
            WB_ALUResult <= MEM_ALUResult;
            WB_WriteReg  <= MEM_WriteReg;
            WB_MemToReg  <= MEM_MemToReg;
            WB_RegWrite  <= MEM_RegWrite;
            WB_Link      <= MEM_Link;
        end
    end
endmodule

module HazardDetectionUnit (
    input             EX_MemRead,
    input      [3:0] EX_WriteReg,
    input      [3:0] ID_Rs, ID_RtSrc,
    output reg       PCWrite, IF_ID_Write, ID_EX_Flush
);
    always @(*) begin
        if (EX_MemRead && (EX_WriteReg != 4'd0) &&
            ((EX_WriteReg == ID_Rs) || (EX_WriteReg == ID_RtSrc))) begin
            PCWrite     = 1'b0;
            IF_ID_Write = 1'b0;
            ID_EX_Flush = 1'b1;
        end else begin
            PCWrite     = 1'b1;
            IF_ID_Write = 1'b1;
            ID_EX_Flush = 1'b0;
        end
    end
endmodule

module ForwardingUnit (
    input      [3:0] EX_Rs, EX_RtSrc, MEM_WriteReg, WB_WriteReg,
    input            MEM_RegWrite, WB_RegWrite,
    output reg [1:0] ForwardA, ForwardB
);
    always @(*) begin
        ForwardA = 2'b00;
        ForwardB = 2'b00;

        if (MEM_RegWrite && (MEM_WriteReg != 4'd0) && (MEM_WriteReg == EX_Rs))
            ForwardA = 2'b10;
        else if (WB_RegWrite && (WB_WriteReg != 4'd0) && (WB_WriteReg == EX_Rs))
            ForwardA = 2'b01;

        if (MEM_RegWrite && (MEM_WriteReg != 4'd0) && (MEM_WriteReg == EX_RtSrc))
            ForwardB = 2'b10;
        else if (WB_RegWrite && (WB_WriteReg != 4'd0) && (WB_WriteReg == EX_RtSrc))
            ForwardB = 2'b01;
    end
endmodule

module Processor (
    input  CLK, RST,
    input         IMem_WrEn,
    input  [7:0]  IMem_WrAddr,
    input  [31:0] IMem_WrData,
    output [31:0] dbg_PC,
    output [31:0] dbg_R1, dbg_R2, dbg_R3, dbg_R4, dbg_R5, dbg_R6,
    output [31:0] dbg_R0, dbg_R7, dbg_R14, dbg_MEM0
);
    wire [31:0] PC_Out, PC_Next, IF_Instruction;
    wire        PCWrite_hazard, IF_ID_Write;

    wire [31:0] ID_PC, ID_Instruction;
    wire [5:0]  ID_Opcode = ID_Instruction[31:26];
    wire [3:0]  ID_DestReg = ID_Instruction[25:22];       // Rd for R-Type, Rt for I-Type
    wire [3:0]  ID_Rs      = ID_Instruction[21:18];       // Rs
    wire [3:0]  ID_Rt_R    = ID_Instruction[17:14];       // Rt for R-Type
    wire [17:0] ID_Imm18   = ID_Instruction[17:0];
    wire [25:0] ID_Offset26= ID_Instruction[25:0];

    // Second register source:
    // R-Type arithmetic/logic/shift uses Rt field [17:14].
    // SW, SWAP, BEQ, BNE use Rt field [25:22].
    wire ID_RType_UsesRt = (ID_Opcode >= 6'd0 && ID_Opcode <= 6'd7);
    wire [3:0] ID_RtSrc  = ID_RType_UsesRt ? ID_Rt_R : ID_DestReg;

    wire ID_ALUSrc, ID_MemRead, ID_MemWrite, ID_MemToReg, ID_RegWrite;
    wire ID_Branch, ID_Jump, ID_Link, ID_JR, ID_SignOrZero, ID_Halt;
    wire [31:0] ID_ReadData1, ID_ReadData2, ID_ExtImm;

    reg halted;
    always @(posedge CLK or negedge RST) begin
        if (~RST) halted <= 1'b0;
        else if (ID_Halt) halted <= 1'b1;
    end

    wire MEM_BranchTaken;
    wire EX_Jump, EX_JR;
    wire PCWrite = PCWrite_hazard & ~halted & ~ID_Halt;

    wire WB_RegWrite_sig;
    wire [3:0]  WB_WriteReg_sig;
    wire [31:0] WB_WriteData_sig;

    wire ID_EX_Flush_hazard;
    wire ID_EX_Flush  = ID_EX_Flush_hazard | MEM_BranchTaken | EX_Jump | EX_JR;
    wire IF_ID_Flush  = MEM_BranchTaken | EX_Jump | EX_JR;
    wire EX_MEM_Flush = MEM_BranchTaken;

    wire [31:0] EX_PC, EX_ReadData1, EX_ReadData2, EX_ExtImm;
    wire [3:0]  EX_Rs, EX_RtSrc, EX_DestReg;
    wire [25:0] EX_Offset26;
    wire        EX_ALUSrc, EX_MemRead, EX_MemWrite, EX_MemToReg, EX_RegWrite;
    wire        EX_Branch, EX_Link;
    wire [5:0]  EX_Opcode;

    wire [1:0]  ForwardA, ForwardB;
    wire [31:0] MEM_ForwardData;
    wire [31:0] EX_ForwardedA, EX_ForwardedB;
    wire [31:0] EX_ALUOperandA, EX_ALUOperandB;
    wire [31:0] EX_ALUResult, EX_BranchTarget, EX_LinkAddr, EX_JumpTarget;
    wire [31:0] EX_Offset26Ext;
    wire        EX_Zero;
    wire [3:0]  EX_WriteReg;

    wire [31:0] MEM_BranchTarget, MEM_LinkAddr, MEM_ALUResult, MEM_WriteData, MEM_ReadData;
    wire [3:0]  MEM_WriteReg;
    wire        MEM_Zero, MEM_MemRead, MEM_MemWrite, MEM_MemToReg, MEM_RegWrite, MEM_Branch, MEM_Link;
    wire [5:0]  MEM_Opcode;

    wire [31:0] WB_LinkAddr, WB_ReadData, WB_ALUResult;
    wire [3:0]  WB_WriteReg;
    wire        WB_MemToReg, WB_RegWrite, WB_Link;

    assign dbg_PC = PC_Out;

    PCControl u_PCCtrl (
        .PC_Current  (PC_Out),
        .BranchTarget(MEM_BranchTarget),
        .JumpTarget  (EX_JumpTarget),
        .JRTarget    (EX_ForwardedA),
        .BranchTaken (MEM_BranchTaken),
        .Jump        (EX_Jump),
        .JR          (EX_JR),
        .PC_Next     (PC_Next)
    );

    ProgramCounter u_PC (
        .CLK    (CLK),
        .RST    (RST),
        .PCWrite(PCWrite),
        .PC_Next(PC_Next),
        .PC_Out (PC_Out)
    );

    InstructionMemory u_IMem (
        .Address    (PC_Out),
        .Instruction(IF_Instruction),
        .WrEn       (IMem_WrEn),
        .WrAddr     (IMem_WrAddr),
        .WrData     (IMem_WrData)
    );

    IF_ID_Register u_IF_ID (
        .CLK        (CLK),
        .RST        (RST),
        .IF_ID_Write(IF_ID_Write),
        .IF_ID_Flush(IF_ID_Flush),
        .IF_PC      (PC_Out),
        .IF_Instr   (IF_Instruction),
        .ID_PC      (ID_PC),
        .ID_Instr   (ID_Instruction)
    );

    ControlUnit u_Ctrl (
        .Opcode    (ID_Opcode),
        .ALUSrc    (ID_ALUSrc),
        .MemRead   (ID_MemRead),
        .MemWrite  (ID_MemWrite),
        .MemToReg  (ID_MemToReg),
        .RegWrite  (ID_RegWrite),
        .Branch    (ID_Branch),
        .Jump      (ID_Jump),
        .Link      (ID_Link),
        .JR        (ID_JR),
        .SignOrZero(ID_SignOrZero),
        .Halt      (ID_Halt)
    );

    RegisterFile u_RF (
        .CLK      (CLK),
        .RST      (RST),
        .RegWrite (WB_RegWrite_sig),
        .ReadReg1 (ID_Rs),
        .ReadReg2 (ID_RtSrc),
        .WriteReg (WB_WriteReg_sig),
        .WriteData(WB_WriteData_sig),
        .ReadData1(ID_ReadData1),
        .ReadData2(ID_ReadData2),
        .R0out    (dbg_R0),
        .R1out    (dbg_R1),
        .R2out    (dbg_R2),
        .R3out    (dbg_R3),
        .R4out    (dbg_R4),
        .R5out    (dbg_R5),
        .R6out    (dbg_R6),
        .R7out    (dbg_R7),
        .R14out   (dbg_R14)
    );

    SignZeroExtend18 u_Ext18 (
        .Imm18     (ID_Imm18),
        .SignOrZero(ID_SignOrZero),
        .ExtImm    (ID_ExtImm)
    );

    ID_EX_Register u_ID_EX (
        .CLK         (CLK),
        .RST         (RST),
        .ID_EX_Flush (ID_EX_Flush),
        .ID_PC       (ID_PC),
        .ID_ReadData1(ID_ReadData1),
        .ID_ReadData2(ID_ReadData2),
        .ID_ExtImm   (ID_ExtImm),
        .ID_Rs       (ID_Rs),
        .ID_RtSrc    (ID_RtSrc),
        .ID_DestReg  (ID_DestReg),
        .ID_Offset26 (ID_Offset26),
        .ID_ALUSrc   (ID_ALUSrc),
        .ID_MemRead  (ID_MemRead),
        .ID_MemWrite (ID_MemWrite),
        .ID_MemToReg (ID_MemToReg),
        .ID_RegWrite (ID_RegWrite),
        .ID_Branch   (ID_Branch),
        .ID_Jump     (ID_Jump),
        .ID_Link     (ID_Link),
        .ID_JR       (ID_JR),
        .ID_Opcode   (ID_Opcode),
        .EX_PC       (EX_PC),
        .EX_ReadData1(EX_ReadData1),
        .EX_ReadData2(EX_ReadData2),
        .EX_ExtImm   (EX_ExtImm),
        .EX_Rs       (EX_Rs),
        .EX_RtSrc    (EX_RtSrc),
        .EX_DestReg  (EX_DestReg),
        .EX_Offset26 (EX_Offset26),
        .EX_ALUSrc   (EX_ALUSrc),
        .EX_MemRead  (EX_MemRead),
        .EX_MemWrite (EX_MemWrite),
        .EX_MemToReg (EX_MemToReg),
        .EX_RegWrite (EX_RegWrite),
        .EX_Branch   (EX_Branch),
        .EX_Jump     (EX_Jump),
        .EX_Link     (EX_Link),
        .EX_JR       (EX_JR),
        .EX_Opcode   (EX_Opcode)
    );

    assign EX_WriteReg = EX_Link ? 4'd14 : EX_DestReg;

    HazardDetectionUnit u_Hazard (
        .EX_MemRead (EX_MemRead),
        .EX_WriteReg(EX_WriteReg),
        .ID_Rs      (ID_Rs),
        .ID_RtSrc   (ID_RtSrc),
        .PCWrite    (PCWrite_hazard),
        .IF_ID_Write(IF_ID_Write),
        .ID_EX_Flush(ID_EX_Flush_hazard)
    );

    ForwardingUnit u_Fwd (
        .EX_Rs       (EX_Rs),
        .EX_RtSrc    (EX_RtSrc),
        .MEM_WriteReg(MEM_WriteReg),
        .WB_WriteReg (WB_WriteReg),
        .MEM_RegWrite(MEM_RegWrite),
        .WB_RegWrite (WB_RegWrite),
        .ForwardA    (ForwardA),
        .ForwardB    (ForwardB)
    );

    // Correct MEM forwarding: JAL forwards LinkAddr, LW cannot forward from MEM directly.
    assign MEM_ForwardData = MEM_Link ? MEM_LinkAddr : MEM_ALUResult;

    assign EX_ForwardedA  = (ForwardA == 2'b10) ? MEM_ForwardData :
                            (ForwardA == 2'b01) ? WB_WriteData_sig :
                                                  EX_ReadData1;
    assign EX_ForwardedB  = (ForwardB == 2'b10) ? MEM_ForwardData :
                            (ForwardB == 2'b01) ? WB_WriteData_sig :
                                                  EX_ReadData2;

    assign EX_ALUOperandA = EX_ForwardedA;
    assign EX_ALUOperandB = EX_ALUSrc ? EX_ExtImm : EX_ForwardedB;

    assign EX_Offset26Ext  = {{6{EX_Offset26[25]}}, EX_Offset26};
    assign EX_BranchTarget = EX_PC + EX_ExtImm;        // Project spec: PC = PC + sign_extend(Imm)
    assign EX_JumpTarget   = EX_PC + EX_Offset26Ext;   // Project spec: PC = PC + sign_extend(Offset26)
    assign EX_LinkAddr     = EX_PC + 32'd1;            // JAL: R14 = PC + 1

    wire [3:0] ALUCtrl;
    ALUControl u_ALUCtrl (
        .Opcode (EX_Opcode),
        .ALUCtrl(ALUCtrl)
    );

    ALU u_ALU (
        .OperandA (EX_ALUOperandA),
        .OperandB (EX_ALUOperandB),
        .ALUCtrl  (ALUCtrl),
        .ALUResult(EX_ALUResult),
        .Zero     (EX_Zero)
    );

    EX_MEM_Register u_EX_MEM (
        .CLK             (CLK),
        .RST             (RST),
        .EX_MEM_Flush    (EX_MEM_Flush),
        .EX_BranchTarget (EX_BranchTarget),
        .EX_LinkAddr     (EX_LinkAddr),
        .EX_ALUResult    (EX_ALUResult),
        .EX_WriteData    (EX_ForwardedB),
        .EX_WriteReg     (EX_WriteReg),
        .EX_Zero         (EX_Zero),
        .EX_MemRead      (EX_MemRead),
        .EX_MemWrite     (EX_MemWrite),
        .EX_MemToReg     (EX_MemToReg),
        .EX_RegWrite     (EX_RegWrite),
        .EX_Branch       (EX_Branch),
        .EX_Link         (EX_Link),
        .EX_Opcode       (EX_Opcode),
        .MEM_BranchTarget(MEM_BranchTarget),
        .MEM_LinkAddr    (MEM_LinkAddr),
        .MEM_ALUResult   (MEM_ALUResult),
        .MEM_WriteData   (MEM_WriteData),
        .MEM_WriteReg    (MEM_WriteReg),
        .MEM_Zero        (MEM_Zero),
        .MEM_MemRead     (MEM_MemRead),
        .MEM_MemWrite    (MEM_MemWrite),
        .MEM_MemToReg    (MEM_MemToReg),
        .MEM_RegWrite    (MEM_RegWrite),
        .MEM_Branch      (MEM_Branch),
        .MEM_Link        (MEM_Link),
        .MEM_Opcode      (MEM_Opcode)
    );

    DataMemory u_DMem (
        .CLK      (CLK),
        .RST      (RST),
        .MemRead  (MEM_MemRead),
        .MemWrite (MEM_MemWrite),
        .Address  (MEM_ALUResult),
        .WriteData(MEM_WriteData),
        .ReadData (MEM_ReadData),
        .Mem0out  (dbg_MEM0)
    );

    assign MEM_BranchTaken = MEM_Branch &&
                             ((MEM_Opcode == 6'd16 &&  MEM_Zero) ||
                              (MEM_Opcode == 6'd17 && ~MEM_Zero));

    MEM_WB_Register u_MEM_WB (
        .CLK         (CLK),
        .RST         (RST),
        .MEM_LinkAddr(MEM_LinkAddr),
        .MEM_ReadData(MEM_ReadData),
        .MEM_ALUResult(MEM_ALUResult),
        .MEM_WriteReg(MEM_WriteReg),
        .MEM_MemToReg(MEM_MemToReg),
        .MEM_RegWrite(MEM_RegWrite),
        .MEM_Link    (MEM_Link),
        .WB_LinkAddr (WB_LinkAddr),
        .WB_ReadData (WB_ReadData),
        .WB_ALUResult(WB_ALUResult),
        .WB_WriteReg (WB_WriteReg),
        .WB_MemToReg (WB_MemToReg),
        .WB_RegWrite (WB_RegWrite),
        .WB_Link     (WB_Link)
    );

    assign WB_WriteData_sig = WB_Link     ? WB_LinkAddr  :
                              WB_MemToReg ? WB_ReadData  :
                                            WB_ALUResult;
    assign WB_RegWrite_sig  = WB_RegWrite;
    assign WB_WriteReg_sig  = WB_WriteReg;

endmodule
