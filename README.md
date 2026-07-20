# 32-bit Pipelined RISC Processor

A modular **32-bit RISC processor** implemented in Verilog HDL for the ENCS4370 Computer Architecture course at Birzeit University. The design uses a classic five-stage pipeline and supports arithmetic, logical, memory, branch, jump, and custom instructions.

## Project Overview

The processor follows a Harvard-style organization with separate instruction and data memories. It includes:

- Five pipeline stages: **IF, ID, EX, MEM, and WB**
- Sixteen 32-bit general-purpose registers
- 32-bit instruction and data paths
- Hazard detection for load-use dependencies
- Data forwarding to reduce pipeline stalls
- Branch and jump control
- Custom `CLR`, `JR`, and `SWAP` instructions
- A self-checking Verilog testbench with three test programs

## Supported Instructions

| Type | Instructions |
|---|---|
| R-Type | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `NOR`, `SLL`, `SRL`, `CLR`, `JR` |
| I-Type | `ADDI`, `ANDI`, `ORI`, `LW`, `SW`, `SWAP`, `BEQ`, `BNE` |
| J-Type | `J`, `JAL` |

The testbench also uses opcode `63` as a simulation-only `HALT` instruction.

## Repository Structure

```text
.
├── src/
│   └── processor.v                  # Processor modules and top-level design
├── tb/
│   └── processor_tb.v               # Self-checking testbench
├── programs/
│   ├── assembly/                    # Human-readable assembly test programs
│   └── machine-code/                # Binary, hexadecimal, and memory images
├── simulation/
│   └── simulation_results.txt       # Recorded simulation trace and PASS results
├── docs/
│   └── Project_Report.pdf           # Full design and verification report
├── .gitignore
└── README.md
```

## Main Verilog Modules

The implementation contains the following modules:

- `ProgramCounter`
- `PCControl`
- `InstructionMemory`
- `IF_ID_Register`
- `RegisterFile`
- `ControlUnit`
- `SignZeroExtend18`
- `ID_EX_Register`
- `ALUControl`
- `ALU`
- `EX_MEM_Register`
- `DataMemory`
- `MEM_WB_Register`
- `HazardDetectionUnit`
- `ForwardingUnit`
- `Processor`

## Test Programs

### Program 1 - Arithmetic, Logic, Memory, and SWAP

Exercises arithmetic operations, logical operations, shifts, `CLR`, `LW`, `SW`, and `SWAP`.

Expected final values include:

```text
R0=0, R1=5, R2=5, R3=15, R4=5,
R5=10, R6=10, R7=15, MEM[0]=10
```

### Program 2 - Branch and Jump Operations

Exercises `BEQ`, `BNE`, `J`, `JAL`, and `JR`.

Expected final values include:

```text
R1=5, R2=5, R3=7, R4=4, R5=20, R6=77, R14=14
```

### Program 3 - Forwarding and Load-Use Hazard

Verifies forwarding paths, memory access, and load-use hazard handling.

Expected final values include:

```text
R1=4, R2=8, R3=12, R4=12, R5=16, MEM[0]=12
```

## Running the Simulation

### ModelSim / QuestaSim / Riviera-PRO

From the repository root:

```tcl
vlib work
vlog src/processor.v tb/processor_tb.v
vsim processor_tb
run -all
```

For command-line execution in ModelSim or QuestaSim:

```bash
vlib work
vlog src/processor.v tb/processor_tb.v
vsim -c processor_tb -do "run -all; quit"
```

### Icarus Verilog

```bash
mkdir -p build
iverilog -g2012 -o build/processor_tb.out src/processor.v tb/processor_tb.v
vvp build/processor_tb.out
```

A successful run prints `PASS` messages for the expected register and memory values. A previously recorded run is available in [`simulation/simulation_results.txt`](simulation/simulation_results.txt).

## Instruction Formats

```text
R-Type: opcode[31:26] | Rd[25:22] | Rs[21:18] | Rt[17:14] | unused[13:0]
I-Type: opcode[31:26] | Rt[25:22] | Rs[21:18] | immediate[17:0]
J-Type: opcode[31:26] | offset[25:0]
```

## Team

- Mohammad Abdallah 
- Khaled Bani Oudeh 
- Motaz Taysir 

## Documentation

The complete report, including the datapath, control signals, pipeline design, ISA details, hazard handling, waveforms, and verification results, is available in [`docs/Project_Report.pdf`](docs/Project_Report.pdf).
