; ENCS4370 Project 2 - program3_forwarding_load_use
; Expected final result: R1=4, R2=8, R3=12, R4=12, R5=16, MEM0=12

00: ADDI R1, R0, 4
01: ADD  R2, R1, R1
02: ADD  R3, R2, R1
03: SW   R3, 0(R0)
04: LW   R4, 0(R0)
05: ADD  R5, R4, R1
06: HALT
