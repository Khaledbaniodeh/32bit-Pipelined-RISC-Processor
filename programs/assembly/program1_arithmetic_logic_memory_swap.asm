; ENCS4370 Project 2 - program1_arithmetic_logic_memory_swap
; Expected final result: R0=0, R1=5, R2=5, R3=15, R4=5, R5=10, R6=10, R7=15, MEM0=10

00: ADDI R1, R0, 5
01: ADDI R2, R0, 10
02: ADD  R3, R1, R2
03: SUB  R4, R2, R1
04: AND  R5, R1, R2
05: OR   R6, R1, R2
06: XOR  R7, R1, R2
07: SLL  R6, R1, R1
08: SRL  R6, R6, R1
09: CLR  R5
10: SW   R1, 0(R0)
11: LW   R5, 0(R0)
12: ADD  R6, R5, R1
13: SWAP R2, 0(R0)
14: LW   R5, 0(R0)
15: HALT
