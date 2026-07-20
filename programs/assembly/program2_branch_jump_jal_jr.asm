; ENCS4370 Project 2 - program2_branch_jump_jal_jr
; Expected final result: R1=5, R2=5, R3=7, R4=4, R5=20, R6=77, R14=14

00: ADDI R1, R0, 5
01: ADDI R2, R0, 5
02: BEQ  R1, R2, +5
03: ADDI R3, R0, 99
04: ADDI R4, R0, 99
05: ADDI R5, R0, 99
06: ADDI R6, R0, 99
07: ADDI R3, R0, 7
08: BNE  R1, R2, +3
09: ADDI R4, R0, 4
10: J    +3
11: ADDI R5, R0, 55
12: ADDI R5, R0, 66
13: JAL  +3
14: J    +5
15: ADDI R6, R0, 88
16: ADDI R6, R0, 77
17: JR   R14
18: ADDI R6, R0, 99
19: ADDI R5, R0, 20
20: HALT
